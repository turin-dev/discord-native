#ifndef FLUTTER_WEBRTC_DISCORD_VIDEO_TRANSPORT_H_
#define FLUTTER_WEBRTC_DISCORD_VIDEO_TRANSPORT_H_

#include <cstdint>
#include <memory>
#include <string>
#include <functional>
#include <mutex>
#include <vector>

#include "discord_dave_encryptor.h"
#include "rtc/rtc.hpp"

namespace flutter_webrtc_plugin {

struct DiscordVideoSessionConfig {
  uint32_t audio_ssrc;
  uint32_t video_ssrc;
  uint32_t rtx_ssrc;
  std::string source_kind;
  std::string source_id;
  int width;
  int height;
  int frames_per_second;
};

class DiscordVideoTransport {
 public:
  using AudioFrameCallback =
      std::function<void(uint32_t, uint16_t, std::vector<uint8_t>)>;
  using VideoFrameCallback =
      std::function<void(uint32_t, uint32_t, std::vector<uint8_t>)>;

  DiscordVideoTransport(DiscordVideoSessionConfig config,
                        AudioFrameCallback audio_frame_callback,
                        VideoFrameCallback video_frame_callback);
  ~DiscordVideoTransport();

  DiscordVideoTransport(const DiscordVideoTransport&) = delete;
  DiscordVideoTransport& operator=(const DiscordVideoTransport&) = delete;

  std::string CreateOffer();
  void AcceptAnswer(const std::string& sdp,
                    const std::string& video_codec,
                    uintptr_t dave_encryptor_address);
  void SendAudioFrame(const std::vector<uint8_t>& opus_frame,
                      int duration_milliseconds);
  void SendVideoFrame(const std::vector<uint8_t>& h264_frame,
                      int duration_milliseconds);
  void Close();

  const DiscordVideoSessionConfig& config() const { return config_; }

 private:
  void CreateTracks();

  const DiscordVideoSessionConfig config_;
  std::unique_ptr<rtc::PeerConnection> peer_connection_;
  std::shared_ptr<rtc::Track> audio_track_;
  std::shared_ptr<rtc::Track> video_track_;
  std::shared_ptr<rtc::RtpPacketizationConfig> audio_rtp_config_;
  std::shared_ptr<rtc::RtpPacketizationConfig> video_rtp_config_;
  DiscordDaveEncryptor dave_encryptor_;
  std::mutex encryptor_mutex_;
  uintptr_t dave_encryptor_address_ = 0;
  bool offer_created_ = false;
  bool answer_accepted_ = false;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_DISCORD_VIDEO_TRANSPORT_H_
