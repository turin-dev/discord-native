#include "discord_h264_capture_encoder.h"

#include <algorithm>
#include <cstring>
#include <stdexcept>
#include <utility>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mftransform.h>
#include <wrl/client.h>

namespace flutter_webrtc_plugin {

namespace {

using Microsoft::WRL::ComPtr;

constexpr UINT32 kVideoBitrate = 4000000;
constexpr LONGLONG kHundredNanosecondsPerSecond = 10000000;

void ThrowIfFailed(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + " failed: " +
                             std::to_string(result));
  }
}

std::vector<uint8_t> ConvertToNv12(
    const libwebrtc::scoped_refptr<libwebrtc::RTCVideoFrame>& frame) {
  const int width = frame->width();
  const int height = frame->height();
  if (width < 2 || height < 2 || width % 2 != 0 || height % 2 != 0) {
    throw std::invalid_argument("Camera frame dimensions must be even");
  }
  const size_t y_size = static_cast<size_t>(width) * height;
  std::vector<uint8_t> nv12(y_size + y_size / 2);
  for (int row = 0; row < height; ++row) {
    std::memcpy(nv12.data() + static_cast<size_t>(row) * width,
                frame->DataY() + static_cast<size_t>(row) * frame->StrideY(),
                width);
  }
  uint8_t* uv = nv12.data() + y_size;
  for (int row = 0; row < height / 2; ++row) {
    const uint8_t* source_u =
        frame->DataU() + static_cast<size_t>(row) * frame->StrideU();
    const uint8_t* source_v =
        frame->DataV() + static_cast<size_t>(row) * frame->StrideV();
    for (int column = 0; column < width / 2; ++column) {
      const size_t target = static_cast<size_t>(row) * width + column * 2;
      uv[target] = source_u[column];
      uv[target + 1] = source_v[column];
    }
  }
  return nv12;
}

bool HasAnnexBStartCode(const std::vector<uint8_t>& frame) {
  return frame.size() >= 4 && frame[0] == 0 && frame[1] == 0 &&
         (frame[2] == 1 || (frame[2] == 0 && frame[3] == 1));
}

std::vector<uint8_t> NormalizeAnnexB(const std::vector<uint8_t>& encoded) {
  if (HasAnnexBStartCode(encoded)) {
    return encoded;
  }
  std::vector<uint8_t> normalized;
  size_t offset = 0;
  while (offset + 4 <= encoded.size()) {
    const uint32_t length =
        (static_cast<uint32_t>(encoded[offset]) << 24) |
        (static_cast<uint32_t>(encoded[offset + 1]) << 16) |
        (static_cast<uint32_t>(encoded[offset + 2]) << 8) |
        static_cast<uint32_t>(encoded[offset + 3]);
    offset += 4;
    if (length == 0 || length > encoded.size() - offset) {
      throw std::runtime_error("H264 encoder returned an invalid access unit");
    }
    normalized.insert(normalized.end(), {0, 0, 0, 1});
    normalized.insert(normalized.end(), encoded.begin() + offset,
                      encoded.begin() + offset + length);
    offset += length;
  }
  if (offset != encoded.size() || normalized.empty()) {
    throw std::runtime_error("H264 encoder output is not Annex B or AVCC");
  }
  return normalized;
}

class MediaFoundationH264Encoder {
 public:
  MediaFoundationH264Encoder(int frames_per_second,
                             DiscordH264CaptureEncoder::FrameCallback callback)
      : frames_per_second_(frames_per_second),
        duration_(kHundredNanosecondsPerSecond / frames_per_second),
        callback_(std::move(callback)) {}

  ~MediaFoundationH264Encoder() {
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
  }

  void Encode(int width, int height, const std::vector<uint8_t>& nv12) {
    if (!transform_ || width != width_ || height != height_) {
      Configure(width, height);
    }
    ComPtr<IMFMediaBuffer> buffer;
    ThrowIfFailed(
        MFCreateMemoryBuffer(static_cast<DWORD>(nv12.size()), &buffer),
        "MFCreateMemoryBuffer");
    BYTE* destination = nullptr;
    DWORD capacity = 0;
    ThrowIfFailed(buffer->Lock(&destination, &capacity, nullptr),
                  "IMFMediaBuffer::Lock");
    if (capacity < nv12.size()) {
      buffer->Unlock();
      throw std::runtime_error("Media Foundation input buffer is too small");
    }
    std::memcpy(destination, nv12.data(), nv12.size());
    ThrowIfFailed(buffer->Unlock(), "IMFMediaBuffer::Unlock");
    ThrowIfFailed(buffer->SetCurrentLength(static_cast<DWORD>(nv12.size())),
                  "IMFMediaBuffer::SetCurrentLength");

    ComPtr<IMFSample> sample;
    ThrowIfFailed(MFCreateSample(&sample), "MFCreateSample");
    ThrowIfFailed(sample->AddBuffer(buffer.Get()), "IMFSample::AddBuffer");
    ThrowIfFailed(sample->SetSampleTime(timestamp_),
                  "IMFSample::SetSampleTime");
    ThrowIfFailed(sample->SetSampleDuration(duration_),
                  "IMFSample::SetSampleDuration");
    ThrowIfFailed(transform_->ProcessInput(input_stream_id_, sample.Get(), 0),
                  "IMFTransform::ProcessInput");
    timestamp_ += duration_;
    DrainOutput();
  }

 private:
  void Configure(int width, int height) {
    transform_.Reset();
    width_ = width;
    height_ = height;
    timestamp_ = 0;
    MFT_REGISTER_TYPE_INFO output_info{MFMediaType_Video,
                                       MFVideoFormat_H264};
    IMFActivate** activations = nullptr;
    UINT32 activation_count = 0;
    const UINT32 flags = MFT_ENUM_FLAG_SYNCMFT | MFT_ENUM_FLAG_LOCALMFT |
                         MFT_ENUM_FLAG_SORTANDFILTER;
    ThrowIfFailed(MFTEnumEx(MFT_CATEGORY_VIDEO_ENCODER, flags, nullptr,
                            &output_info, &activations, &activation_count),
                  "MFTEnumEx");
    if (activation_count == 0) {
      CoTaskMemFree(activations);
      throw std::runtime_error("No Media Foundation H264 encoder is available");
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
    SetOutputType();
    SetInputType();
    ThrowIfFailed(transform_->ProcessMessage(MFT_MESSAGE_NOTIFY_BEGIN_STREAMING,
                                             0),
                  "MFT begin streaming");
    ThrowIfFailed(transform_->ProcessMessage(MFT_MESSAGE_NOTIFY_START_OF_STREAM,
                                             0),
                  "MFT start stream");
  }

  void SetOutputType() {
    ComPtr<IMFMediaType> type;
    ThrowIfFailed(MFCreateMediaType(&type), "MFCreateMediaType output");
    ThrowIfFailed(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video),
                  "MF_MT_MAJOR_TYPE output");
    ThrowIfFailed(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264),
                  "MF_MT_SUBTYPE output");
    ThrowIfFailed(MFSetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, width_,
                                     height_),
                  "MF_MT_FRAME_SIZE output");
    ThrowIfFailed(MFSetAttributeRatio(type.Get(), MF_MT_FRAME_RATE,
                                      frames_per_second_, 1),
                  "MF_MT_FRAME_RATE output");
    ThrowIfFailed(MFSetAttributeRatio(type.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1,
                                      1),
                  "MF_MT_PIXEL_ASPECT_RATIO output");
    ThrowIfFailed(type->SetUINT32(MF_MT_AVG_BITRATE, kVideoBitrate),
                  "MF_MT_AVG_BITRATE");
    ThrowIfFailed(type->SetUINT32(MF_MT_INTERLACE_MODE,
                                  MFVideoInterlace_Progressive),
                  "MF_MT_INTERLACE_MODE output");
    ThrowIfFailed(transform_->SetOutputType(output_stream_id_, type.Get(), 0),
                  "IMFTransform::SetOutputType");
  }

  void SetInputType() {
    ComPtr<IMFMediaType> type;
    ThrowIfFailed(MFCreateMediaType(&type), "MFCreateMediaType input");
    ThrowIfFailed(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video),
                  "MF_MT_MAJOR_TYPE input");
    ThrowIfFailed(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_NV12),
                  "MF_MT_SUBTYPE input");
    ThrowIfFailed(MFSetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, width_,
                                     height_),
                  "MF_MT_FRAME_SIZE input");
    ThrowIfFailed(MFSetAttributeRatio(type.Get(), MF_MT_FRAME_RATE,
                                      frames_per_second_, 1),
                  "MF_MT_FRAME_RATE input");
    ThrowIfFailed(type->SetUINT32(MF_MT_INTERLACE_MODE,
                                  MFVideoInterlace_Progressive),
                  "MF_MT_INTERLACE_MODE input");
    ThrowIfFailed(transform_->SetInputType(input_stream_id_, type.Get(), 0),
                  "IMFTransform::SetInputType");
  }

  void DrainOutput() {
    MFT_OUTPUT_STREAM_INFO stream_info{};
    ThrowIfFailed(transform_->GetOutputStreamInfo(output_stream_id_,
                                                   &stream_info),
                  "IMFTransform::GetOutputStreamInfo");
    for (;;) {
      MFT_OUTPUT_DATA_BUFFER output{};
      output.dwStreamID = output_stream_id_;
      ComPtr<IMFSample> output_sample;
      if ((stream_info.dwFlags & MFT_OUTPUT_STREAM_PROVIDES_SAMPLES) == 0) {
        CreateOutputSample(stream_info.cbSize, &output_sample);
        output.pSample = output_sample.Get();
      }
      DWORD status = 0;
      const HRESULT result =
          transform_->ProcessOutput(0, 1, &output, &status);
      if (output.pEvents != nullptr) {
        output.pEvents->Release();
      }
      if (result == MF_E_TRANSFORM_NEED_MORE_INPUT) {
        return;
      }
      ThrowIfFailed(result, "IMFTransform::ProcessOutput");
      IMFSample* produced = output.pSample;
      if (produced == nullptr) {
        throw std::runtime_error("H264 encoder returned no output sample");
      }
      const std::vector<uint8_t> bytes = ReadSample(produced);
      if (!bytes.empty()) {
        callback_(NormalizeAnnexB(bytes),
                  (std::max)(1, 1000 / frames_per_second_));
      }
    }
  }

  static void CreateOutputSample(DWORD buffer_size,
                                 ComPtr<IMFSample>* sample) {
    ThrowIfFailed(MFCreateSample(sample->GetAddressOf()),
                  "MFCreateSample output");
    ComPtr<IMFMediaBuffer> buffer;
    const DWORD capacity = std::max<DWORD>(buffer_size, 1024 * 1024);
    ThrowIfFailed(MFCreateMemoryBuffer(capacity, &buffer),
                  "MFCreateMemoryBuffer output");
    ThrowIfFailed((*sample)->AddBuffer(buffer.Get()),
                  "IMFSample::AddBuffer output");
  }

  static std::vector<uint8_t> ReadSample(IMFSample* sample) {
    ComPtr<IMFMediaBuffer> buffer;
    ThrowIfFailed(sample->ConvertToContiguousBuffer(&buffer),
                  "IMFSample::ConvertToContiguousBuffer");
    BYTE* data = nullptr;
    DWORD length = 0;
    ThrowIfFailed(buffer->Lock(&data, nullptr, &length),
                  "IMFMediaBuffer::Lock output");
    std::vector<uint8_t> bytes(data, data + length);
    ThrowIfFailed(buffer->Unlock(), "IMFMediaBuffer::Unlock output");
    return bytes;
  }

  const int frames_per_second_;
  const LONGLONG duration_;
  DiscordH264CaptureEncoder::FrameCallback callback_;
  ComPtr<IMFTransform> transform_;
  DWORD input_stream_id_ = 0;
  DWORD output_stream_id_ = 0;
  int width_ = 0;
  int height_ = 0;
  LONGLONG timestamp_ = 0;
  bool com_initialized_ = false;
  bool media_foundation_started_ = false;
};

}  // namespace

DiscordH264CaptureEncoder::DiscordH264CaptureEncoder(
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoTrack> track,
    int frames_per_second,
    FrameCallback frame_callback,
    ErrorCallback error_callback)
    : track_(std::move(track)),
      frames_per_second_(frames_per_second),
      frame_callback_(std::move(frame_callback)),
      error_callback_(std::move(error_callback)) {
  if (!track_ || frames_per_second < 1 || frames_per_second > 60) {
    throw std::invalid_argument("Invalid Discord video capture configuration");
  }
}

DiscordH264CaptureEncoder::~DiscordH264CaptureEncoder() {
  Stop();
}

void DiscordH264CaptureEncoder::Start() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (running_) {
    throw std::logic_error("Discord video capture is already running");
  }
  running_ = true;
  stopping_ = false;
  error_reported_ = false;
  worker_ = std::thread(&DiscordH264CaptureEncoder::WorkerLoop, this);
  track_->AddRenderer(this);
}

void DiscordH264CaptureEncoder::Stop() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!running_ && !worker_.joinable()) {
      return;
    }
    running_ = false;
    stopping_ = true;
    pending_frame_.reset();
  }
  track_->RemoveRenderer(this);
  condition_.notify_all();
  if (worker_.joinable()) {
    worker_.join();
  }
}

void DiscordH264CaptureEncoder::OnFrame(
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoFrame> frame) {
  try {
    auto pending = std::make_unique<PendingFrame>(PendingFrame{
        frame->width(), frame->height(), ConvertToNv12(frame)});
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (!running_ || stopping_) {
        return;
      }
      pending_frame_ = std::move(pending);
    }
    condition_.notify_one();
  } catch (const std::exception& error) {
    ReportError(error.what());
  }
}

void DiscordH264CaptureEncoder::WorkerLoop() {
  try {
    MediaFoundationH264Encoder encoder(frames_per_second_, frame_callback_);
    encoder.Initialize();
    for (;;) {
      std::unique_ptr<PendingFrame> frame;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait(lock,
                        [this] { return stopping_ || pending_frame_ != nullptr; });
        if (stopping_) {
          return;
        }
        frame = std::move(pending_frame_);
      }
      encoder.Encode(frame->width, frame->height, frame->nv12);
    }
  } catch (const std::exception& error) {
    ReportError(error.what());
  }
}

void DiscordH264CaptureEncoder::ReportError(const std::string& message) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (error_reported_) {
      return;
    }
    error_reported_ = true;
    running_ = false;
    stopping_ = true;
  }
  condition_.notify_all();
  error_callback_(message);
}

}  // namespace flutter_webrtc_plugin
