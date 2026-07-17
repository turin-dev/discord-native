#include "discord_h264_render_decoder.h"

#include <algorithm>
#include <cstring>
#include <stdexcept>
#include <utility>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mftransform.h>
#include <wrl/client.h>

#include "rtc_video_frame.h"

namespace flutter_webrtc_plugin {

namespace {

using Microsoft::WRL::ComPtr;

constexpr size_t kMaximumPendingFrames = 120;
constexpr LONGLONG kHundredNanosecondsPerSecond = 10000000;
constexpr DWORD kMaximumNv12FrameBytes = 3840 * 2160 * 3 / 2;

void ThrowIfFailed(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + " failed: " +
                             std::to_string(result));
  }
}

bool IsKeyFrame(const std::vector<uint8_t>& frame) {
  for (size_t index = 0; index + 3 < frame.size(); ++index) {
    size_t header = 0;
    if (frame[index] == 0 && frame[index + 1] == 0 &&
        frame[index + 2] == 1) {
      header = index + 3;
    } else if (index + 4 < frame.size() && frame[index] == 0 &&
               frame[index + 1] == 0 && frame[index + 2] == 0 &&
               frame[index + 3] == 1) {
      header = index + 4;
    }
    if (header < frame.size() && (frame[header] & 0x1F) == 5) {
      return true;
    }
  }
  return false;
}

class MediaFoundationH264Decoder {
 public:
  explicit MediaFoundationH264Decoder(
      libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source)
      : source_(std::move(source)) {}

  ~MediaFoundationH264Decoder() {
    transform_.Reset();
    if (media_foundation_started_) {
      MFShutdown();
    }
    if (com_initialized_) {
      CoUninitialize();
    }
  }

  void Initialize() {
    const HRESULT com_result = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (SUCCEEDED(com_result)) {
      com_initialized_ = true;
    } else if (com_result != RPC_E_CHANGED_MODE) {
      ThrowIfFailed(com_result, "CoInitializeEx");
    }
    ThrowIfFailed(MFStartup(MF_VERSION), "MFStartup");
    media_foundation_started_ = true;
    ConfigureTransform();
  }

  void Decode(const std::vector<uint8_t>& frame, uint32_t timestamp) {
    ComPtr<IMFMediaBuffer> buffer;
    ThrowIfFailed(
        MFCreateMemoryBuffer(static_cast<DWORD>(frame.size()), &buffer),
        "MFCreateMemoryBuffer");
    BYTE* destination = nullptr;
    DWORD capacity = 0;
    ThrowIfFailed(buffer->Lock(&destination, &capacity, nullptr),
                  "IMFMediaBuffer::Lock");
    if (capacity < frame.size()) {
      buffer->Unlock();
      throw std::runtime_error("Media Foundation input buffer is too small");
    }
    std::memcpy(destination, frame.data(), frame.size());
    ThrowIfFailed(buffer->Unlock(), "IMFMediaBuffer::Unlock");
    ThrowIfFailed(buffer->SetCurrentLength(static_cast<DWORD>(frame.size())),
                  "IMFMediaBuffer::SetCurrentLength");

    ComPtr<IMFSample> sample;
    ThrowIfFailed(MFCreateSample(&sample), "MFCreateSample");
    ThrowIfFailed(sample->AddBuffer(buffer.Get()), "IMFSample::AddBuffer");
    const LONGLONG sample_time =
        static_cast<LONGLONG>(timestamp) * kHundredNanosecondsPerSecond /
        90000;
    ThrowIfFailed(sample->SetSampleTime(sample_time),
                  "IMFSample::SetSampleTime");
    ThrowIfFailed(transform_->ProcessInput(input_stream_id_, sample.Get(), 0),
                  "IMFTransform::ProcessInput");
    DrainOutput();
  }

 private:
  void ConfigureTransform() {
    MFT_REGISTER_TYPE_INFO input_info{MFMediaType_Video, MFVideoFormat_H264};
    IMFActivate** activations = nullptr;
    UINT32 activation_count = 0;
    const UINT32 flags = MFT_ENUM_FLAG_SYNCMFT | MFT_ENUM_FLAG_LOCALMFT |
                         MFT_ENUM_FLAG_SORTANDFILTER;
    ThrowIfFailed(MFTEnumEx(MFT_CATEGORY_VIDEO_DECODER, flags, &input_info,
                            nullptr, &activations, &activation_count),
                  "MFTEnumEx");
    if (activation_count == 0) {
      CoTaskMemFree(activations);
      throw std::runtime_error("No Media Foundation H264 decoder is available");
    }
    const HRESULT activate_result =
        activations[0]->ActivateObject(IID_PPV_ARGS(&transform_));
    for (UINT32 index = 0; index < activation_count; ++index) {
      activations[index]->Release();
    }
    CoTaskMemFree(activations);
    ThrowIfFailed(activate_result, "IMFActivate::ActivateObject");

    input_stream_id_ = 0;
    output_stream_id_ = 0;
    const HRESULT ids_result = transform_->GetStreamIDs(
        1, &input_stream_id_, 1, &output_stream_id_);
    if (ids_result != E_NOTIMPL) {
      ThrowIfFailed(ids_result, "IMFTransform::GetStreamIDs");
    }
    SetInputType();
    SelectNv12OutputType();
    ThrowIfFailed(transform_->ProcessMessage(MFT_MESSAGE_NOTIFY_BEGIN_STREAMING,
                                             0),
                  "MFT begin streaming");
    ThrowIfFailed(transform_->ProcessMessage(MFT_MESSAGE_NOTIFY_START_OF_STREAM,
                                             0),
                  "MFT start stream");
  }

  void SetInputType() {
    ComPtr<IMFMediaType> type;
    ThrowIfFailed(MFCreateMediaType(&type), "MFCreateMediaType input");
    ThrowIfFailed(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video),
                  "MF_MT_MAJOR_TYPE input");
    ThrowIfFailed(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264),
                  "MF_MT_SUBTYPE input");
    ThrowIfFailed(type->SetUINT32(MF_MT_INTERLACE_MODE,
                                  MFVideoInterlace_Progressive),
                  "MF_MT_INTERLACE_MODE input");
    ThrowIfFailed(transform_->SetInputType(input_stream_id_, type.Get(), 0),
                  "IMFTransform::SetInputType");
  }

  void SelectNv12OutputType() {
    for (DWORD index = 0;; ++index) {
      IMFMediaType* available = nullptr;
      const HRESULT result = transform_->GetOutputAvailableType(
          output_stream_id_, index, &available);
      if (result == MF_E_NO_MORE_TYPES) {
        break;
      }
      ThrowIfFailed(result, "IMFTransform::GetOutputAvailableType");
      ComPtr<IMFMediaType> type;
      type.Attach(available);
      GUID subtype{};
      if (SUCCEEDED(type->GetGUID(MF_MT_SUBTYPE, &subtype)) &&
          subtype == MFVideoFormat_NV12) {
        ThrowIfFailed(
            transform_->SetOutputType(output_stream_id_, type.Get(), 0),
            "IMFTransform::SetOutputType");
        return;
      }
    }
    throw std::runtime_error("H264 decoder does not support NV12 output");
  }

  void DrainOutput() {
    for (;;) {
      MFT_OUTPUT_STREAM_INFO stream_info{};
      ThrowIfFailed(transform_->GetOutputStreamInfo(output_stream_id_,
                                                     &stream_info),
                    "IMFTransform::GetOutputStreamInfo");
      MFT_OUTPUT_DATA_BUFFER output{};
      output.dwStreamID = output_stream_id_;
      ComPtr<IMFSample> output_sample;
      if ((stream_info.dwFlags & MFT_OUTPUT_STREAM_PROVIDES_SAMPLES) == 0) {
        const DWORD size =
            (std::max)(stream_info.cbSize, kMaximumNv12FrameBytes);
        CreateOutputSample(size, &output_sample);
        output.pSample = output_sample.Get();
      }
      DWORD status = 0;
      const HRESULT result = transform_->ProcessOutput(0, 1, &output, &status);
      if (output.pEvents != nullptr) {
        output.pEvents->Release();
      }
      if (result == MF_E_TRANSFORM_NEED_MORE_INPUT) {
        return;
      }
      if (result == MF_E_TRANSFORM_STREAM_CHANGE) {
        SelectNv12OutputType();
        continue;
      }
      ThrowIfFailed(result, "IMFTransform::ProcessOutput");
      if (output.pSample == nullptr) {
        throw std::runtime_error("H264 decoder returned no output sample");
      }
      EmitSample(output.pSample);
    }
  }

  static void CreateOutputSample(DWORD buffer_size,
                                 ComPtr<IMFSample>* sample) {
    ThrowIfFailed(MFCreateSample(sample->GetAddressOf()),
                  "MFCreateSample output");
    ComPtr<IMFMediaBuffer> buffer;
    ThrowIfFailed(MFCreateMemoryBuffer(buffer_size, &buffer),
                  "MFCreateMemoryBuffer output");
    ThrowIfFailed((*sample)->AddBuffer(buffer.Get()),
                  "IMFSample::AddBuffer output");
  }

  void EmitSample(IMFSample* sample) {
    ComPtr<IMFMediaType> type;
    ThrowIfFailed(transform_->GetOutputCurrentType(output_stream_id_, &type),
                  "IMFTransform::GetOutputCurrentType");
    UINT32 width = 0;
    UINT32 height = 0;
    ThrowIfFailed(MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &width,
                                     &height),
                  "MF_MT_FRAME_SIZE output");
    if (width < 2 || height < 2 || width % 2 != 0 || height % 2 != 0) {
      throw std::runtime_error("H264 decoder returned invalid dimensions");
    }
    UINT32 raw_stride = width;
    type->GetUINT32(MF_MT_DEFAULT_STRIDE, &raw_stride);
    const int32_t signed_stride = static_cast<int32_t>(raw_stride);
    if (signed_stride < static_cast<int32_t>(width)) {
      throw std::runtime_error("H264 decoder returned an invalid NV12 stride");
    }
    const size_t stride = static_cast<size_t>(signed_stride);

    ComPtr<IMFMediaBuffer> buffer;
    ThrowIfFailed(sample->ConvertToContiguousBuffer(&buffer),
                  "IMFSample::ConvertToContiguousBuffer");
    BYTE* data = nullptr;
    DWORD length = 0;
    ThrowIfFailed(buffer->Lock(&data, nullptr, &length),
                  "IMFMediaBuffer::Lock output");
    try {
      const size_t required = stride * height + stride * (height / 2);
      if (length < required) {
        throw std::runtime_error("H264 decoder returned a truncated NV12 frame");
      }
      const size_t y_size = static_cast<size_t>(width) * height;
      const size_t chroma_width = width / 2;
      const size_t chroma_height = height / 2;
      std::vector<uint8_t> y(y_size);
      std::vector<uint8_t> u(chroma_width * chroma_height);
      std::vector<uint8_t> v(chroma_width * chroma_height);
      for (UINT32 row = 0; row < height; ++row) {
        std::memcpy(y.data() + static_cast<size_t>(row) * width,
                    data + static_cast<size_t>(row) * stride, width);
      }
      const BYTE* uv = data + stride * height;
      for (size_t row = 0; row < chroma_height; ++row) {
        for (size_t column = 0; column < chroma_width; ++column) {
          const size_t source = row * stride + column * 2;
          const size_t target = row * chroma_width + column;
          u[target] = uv[source];
          v[target] = uv[source + 1];
        }
      }
      const auto frame = libwebrtc::RTCVideoFrame::Create(
          static_cast<int>(width), static_cast<int>(height), y.data(),
          static_cast<int>(width), u.data(), static_cast<int>(chroma_width),
          v.data(), static_cast<int>(chroma_width));
      if (!frame) {
        throw std::runtime_error("Failed to create a decoded WebRTC frame");
      }
      source_->OnCapturedFrame(frame);
    } catch (...) {
      buffer->Unlock();
      throw;
    }
    ThrowIfFailed(buffer->Unlock(), "IMFMediaBuffer::Unlock output");
  }

  libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source_;
  ComPtr<IMFTransform> transform_;
  DWORD input_stream_id_ = 0;
  DWORD output_stream_id_ = 0;
  bool com_initialized_ = false;
  bool media_foundation_started_ = false;
};

}  // namespace

DiscordH264RenderDecoder::DiscordH264RenderDecoder(
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source,
    ErrorCallback error_callback)
    : source_(std::move(source)), error_callback_(std::move(error_callback)) {
  if (!source_ || !error_callback_) {
    throw std::invalid_argument("Invalid Discord video render configuration");
  }
}

DiscordH264RenderDecoder::~DiscordH264RenderDecoder() {
  Stop();
}

void DiscordH264RenderDecoder::Start() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (running_) {
    throw std::logic_error("Discord video decoder is already running");
  }
  running_ = true;
  stopping_ = false;
  awaiting_key_frame_ = false;
  error_reported_ = false;
  worker_ = std::thread(&DiscordH264RenderDecoder::WorkerLoop, this);
}

void DiscordH264RenderDecoder::Stop() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!running_ && !worker_.joinable()) {
      return;
    }
    running_ = false;
    stopping_ = true;
    pending_frames_.clear();
  }
  condition_.notify_all();
  if (worker_.joinable()) {
    worker_.join();
  }
}

void DiscordH264RenderDecoder::Decode(std::vector<uint8_t> frame,
                                      uint32_t timestamp) {
  if (frame.empty()) {
    throw std::invalid_argument("H264 render frame is required");
  }
  std::lock_guard<std::mutex> lock(mutex_);
  if (!running_ || stopping_) {
    throw std::logic_error("Discord video decoder is not running");
  }
  if (awaiting_key_frame_) {
    if (!IsKeyFrame(frame)) {
      return;
    }
    awaiting_key_frame_ = false;
  }
  if (pending_frames_.size() >= kMaximumPendingFrames) {
    pending_frames_.clear();
    awaiting_key_frame_ = !IsKeyFrame(frame);
    if (awaiting_key_frame_) {
      return;
    }
  }
  pending_frames_.push_back(PendingFrame{std::move(frame), timestamp});
  condition_.notify_one();
}

void DiscordH264RenderDecoder::WorkerLoop() {
  try {
    MediaFoundationH264Decoder decoder(source_);
    decoder.Initialize();
    for (;;) {
      PendingFrame frame;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait(lock, [this] {
          return stopping_ || !pending_frames_.empty();
        });
        if (stopping_) {
          return;
        }
        frame = std::move(pending_frames_.front());
        pending_frames_.pop_front();
      }
      decoder.Decode(frame.bytes, frame.timestamp);
    }
  } catch (const std::exception& error) {
    ReportError(error.what());
  }
}

void DiscordH264RenderDecoder::ReportError(const std::string& message) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (error_reported_) {
      return;
    }
    error_reported_ = true;
    running_ = false;
    stopping_ = true;
    pending_frames_.clear();
  }
  condition_.notify_all();
  error_callback_(message);
}

}  // namespace flutter_webrtc_plugin
