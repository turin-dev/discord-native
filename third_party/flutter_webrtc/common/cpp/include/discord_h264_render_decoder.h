#ifndef FLUTTER_WEBRTC_DISCORD_H264_RENDER_DECODER_H_
#define FLUTTER_WEBRTC_DISCORD_H264_RENDER_DECODER_H_

#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "rtc_types.h"
#include "rtc_video_source.h"

namespace flutter_webrtc_plugin {

class DiscordH264RenderDecoder final {
 public:
  using ErrorCallback = std::function<void(std::string)>;

  DiscordH264RenderDecoder(
      libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source,
      ErrorCallback error_callback);
  ~DiscordH264RenderDecoder();

  DiscordH264RenderDecoder(const DiscordH264RenderDecoder&) = delete;
  DiscordH264RenderDecoder& operator=(const DiscordH264RenderDecoder&) = delete;

  void Start();
  void Stop();
  void Decode(std::vector<uint8_t> frame, uint32_t timestamp);

 private:
  struct PendingFrame {
    std::vector<uint8_t> bytes;
    uint32_t timestamp;
  };

  void WorkerLoop();
  void ReportError(const std::string& message);

  libwebrtc::scoped_refptr<libwebrtc::RTCVideoSource> source_;
  ErrorCallback error_callback_;
  std::mutex mutex_;
  std::condition_variable condition_;
  std::deque<PendingFrame> pending_frames_;
  std::thread worker_;
  bool running_ = false;
  bool stopping_ = false;
  bool awaiting_key_frame_ = false;
  bool error_reported_ = false;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_DISCORD_H264_RENDER_DECODER_H_
