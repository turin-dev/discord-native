#ifndef FLUTTER_WEBRTC_DISCORD_H264_CAPTURE_ENCODER_H_
#define FLUTTER_WEBRTC_DISCORD_H264_CAPTURE_ENCODER_H_

#include <condition_variable>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "rtc_types.h"
#include "rtc_video_frame.h"
#include "rtc_video_renderer.h"
#include "rtc_video_track.h"

namespace flutter_webrtc_plugin {

class DiscordH264CaptureEncoder final
    : public libwebrtc::RTCVideoRenderer<
          libwebrtc::scoped_refptr<libwebrtc::RTCVideoFrame>> {
 public:
  using FrameCallback = std::function<void(std::vector<uint8_t>, int)>;
  using ErrorCallback = std::function<void(std::string)>;

  DiscordH264CaptureEncoder(
      libwebrtc::scoped_refptr<libwebrtc::RTCVideoTrack> track,
      int frames_per_second,
      FrameCallback frame_callback,
      ErrorCallback error_callback);
  ~DiscordH264CaptureEncoder() override;

  DiscordH264CaptureEncoder(const DiscordH264CaptureEncoder&) = delete;
  DiscordH264CaptureEncoder& operator=(const DiscordH264CaptureEncoder&) =
      delete;

  void Start();
  void Stop();
  void OnFrame(
      libwebrtc::scoped_refptr<libwebrtc::RTCVideoFrame> frame) override;

 private:
  struct PendingFrame {
    int width;
    int height;
    std::vector<uint8_t> nv12;
  };

  void WorkerLoop();
  void ReportError(const std::string& message);

  libwebrtc::scoped_refptr<libwebrtc::RTCVideoTrack> track_;
  const int frames_per_second_;
  FrameCallback frame_callback_;
  ErrorCallback error_callback_;
  std::mutex mutex_;
  std::condition_variable condition_;
  std::unique_ptr<PendingFrame> pending_frame_;
  std::thread worker_;
  bool running_ = false;
  bool stopping_ = false;
  bool error_reported_ = false;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_DISCORD_H264_CAPTURE_ENCODER_H_
