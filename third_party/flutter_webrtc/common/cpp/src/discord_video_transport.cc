#include "discord_video_transport.h"

#include <cstddef>
#include <stdexcept>
#include <utility>

#include "rtc/rtcpnackresponder.hpp"
#include "rtc/rtcpsrreporter.hpp"
#include "rtc/h264rtppacketizer.hpp"
#include "rtc/h264rtpdepacketizer.hpp"
#include "rtc/rtp.hpp"

namespace flutter_webrtc_plugin {

namespace {

constexpr uint8_t kOpusPayloadType = 120;
constexpr uint8_t kH264PayloadType = 101;
constexpr uint8_t kRtxPayloadType = 102;
constexpr uint32_t kVideoClockRate = 90000;

class AudioFrameReceiver final : public rtc::MediaHandler {
 public:
  explicit AudioFrameReceiver(DiscordVideoTransport::AudioFrameCallback callback)
      : callback_(std::move(callback)) {}

  void incoming(rtc::message_vector& messages,
                const rtc::message_callback&) override {
    for (const auto& message : messages) {
      if (message->type == rtc::Message::Control ||
          message->size() < sizeof(rtc::RtpHeader)) {
        continue;
      }
      const auto* header =
          reinterpret_cast<const rtc::RtpHeader*>(message->data());
      const size_t header_size =
          header->getSize() + header->getExtensionHeaderSize();
      if (message->size() < header_size) {
        continue;
      }
      std::vector<uint8_t> frame;
      frame.reserve(message->size() - header_size);
      for (auto it = message->begin() + header_size; it != message->end();
           ++it) {
        frame.push_back(std::to_integer<uint8_t>(*it));
      }
      callback_(header->ssrc(), header->seqNumber(), std::move(frame));
    }
    messages.clear();
  }

 private:
  DiscordVideoTransport::AudioFrameCallback callback_;
};

class VideoFrameReceiver final : public rtc::MediaHandler {
 public:
  explicit VideoFrameReceiver(DiscordVideoTransport::VideoFrameCallback callback)
      : callback_(std::move(callback)) {}

  void incoming(rtc::message_vector& messages,
                const rtc::message_callback&) override {
    for (const auto& message : messages) {
      if (message->type == rtc::Message::Control || !message->frameInfo ||
          message->empty()) {
        continue;
      }
      std::vector<uint8_t> frame;
      frame.reserve(message->size());
      for (const auto value : *message) {
        frame.push_back(std::to_integer<uint8_t>(value));
      }
      callback_(message->stream, message->frameInfo->timestamp,
                std::move(frame));
    }
    messages.clear();
  }

 private:
  DiscordVideoTransport::VideoFrameCallback callback_;
};

}  // namespace

DiscordVideoTransport::DiscordVideoTransport(
    DiscordVideoSessionConfig config,
    AudioFrameCallback audio_frame_callback,
    VideoFrameCallback video_frame_callback)
    : config_(std::move(config)),
      peer_connection_(std::make_unique<rtc::PeerConnection>()) {
  CreateTracks();
  auto audio_handler = audio_track_->getMediaHandler();
  audio_handler->setNext(
      std::make_shared<AudioFrameReceiver>(std::move(audio_frame_callback)));
  audio_handler->addToChain(
      std::make_shared<rtc::RtcpSrReporter>(audio_rtp_config_));
  audio_handler->addToChain(std::make_shared<rtc::RtcpNackResponder>());

  auto video_handler = video_track_->getMediaHandler();
  video_handler->setNext(
      std::make_shared<VideoFrameReceiver>(std::move(video_frame_callback)));
  video_handler->addToChain(std::make_shared<rtc::H264RtpDepacketizer>(
      rtc::NalUnit::Separator::StartSequence));
  video_handler->addToChain(
      std::make_shared<rtc::RtcpSrReporter>(video_rtp_config_));
  video_handler->addToChain(std::make_shared<rtc::RtcpNackResponder>());
}

DiscordVideoTransport::~DiscordVideoTransport() {
  Close();
}

std::string DiscordVideoTransport::CreateOffer() {
  if (!peer_connection_) {
    throw std::logic_error("WebRTC session is closed");
  }
  if (offer_created_) {
    throw std::logic_error("WebRTC offer has already been created");
  }
  peer_connection_->setLocalDescription(rtc::Description::Type::Offer);
  const auto description = peer_connection_->localDescription();
  if (!description) {
    throw std::runtime_error("WebRTC local description is unavailable");
  }
  offer_created_ = true;
  return std::string(*description);
}

void DiscordVideoTransport::AcceptAnswer(
    const std::string& sdp,
    const std::string& video_codec,
    uintptr_t dave_encryptor_address) {
  if (!peer_connection_ || !offer_created_) {
    throw std::logic_error("WebRTC offer has not been created");
  }
  if (answer_accepted_) {
    throw std::logic_error("WebRTC answer has already been accepted");
  }
  if (video_codec != "H264") {
    throw std::invalid_argument("Only H264 video is supported");
  }
  if (dave_encryptor_address == 0) {
    throw std::invalid_argument("DAVE encryptor address is required");
  }
  peer_connection_->setRemoteDescription(rtc::Description(sdp, "answer"));
  dave_encryptor_address_ = dave_encryptor_address;
  answer_accepted_ = true;
}

void DiscordVideoTransport::SendAudioFrame(
    const std::vector<uint8_t>& opus_frame,
    int duration_milliseconds) {
  if (!answer_accepted_ || !audio_track_ || !audio_rtp_config_) {
    throw std::logic_error("WebRTC audio session is not ready");
  }
  if (duration_milliseconds < 1 || duration_milliseconds > 60) {
    throw std::invalid_argument("Opus frame duration is outside the range");
  }
  if (!audio_track_->isOpen()) {
    return;
  }
  std::vector<uint8_t> encrypted;
  {
    std::lock_guard<std::mutex> lock(encryptor_mutex_);
    encrypted = dave_encryptor_.EncryptAudio(
        reinterpret_cast<void*>(dave_encryptor_address_), config_.audio_ssrc,
        opus_frame);
  }
  audio_track_->send(reinterpret_cast<const rtc::byte*>(encrypted.data()),
                     encrypted.size());
  audio_rtp_config_->timestamp += static_cast<uint32_t>(
      duration_milliseconds * audio_rtp_config_->clockRate / 1000);
}

void DiscordVideoTransport::SendVideoFrame(
    const std::vector<uint8_t>& h264_frame,
    int duration_milliseconds) {
  if (!answer_accepted_ || !video_track_ || !video_rtp_config_) {
    throw std::logic_error("WebRTC video session is not ready");
  }
  if (duration_milliseconds < 1 || duration_milliseconds > 1000) {
    throw std::invalid_argument("H264 frame duration is outside the range");
  }
  if (!video_track_->isOpen()) {
    return;
  }
  std::vector<uint8_t> encrypted;
  {
    std::lock_guard<std::mutex> lock(encryptor_mutex_);
    encrypted = dave_encryptor_.EncryptVideo(
        reinterpret_cast<void*>(dave_encryptor_address_), config_.video_ssrc,
        h264_frame);
  }
  video_track_->send(reinterpret_cast<const rtc::byte*>(encrypted.data()),
                     encrypted.size());
  video_rtp_config_->timestamp += static_cast<uint32_t>(
      duration_milliseconds * video_rtp_config_->clockRate / 1000);
}

void DiscordVideoTransport::Close() {
  if (!peer_connection_) {
    return;
  }
  peer_connection_->close();
  audio_track_.reset();
  video_track_.reset();
  peer_connection_.reset();
  dave_encryptor_address_ = 0;
  answer_accepted_ = false;
}

void DiscordVideoTransport::CreateTracks() {
  rtc::Description::Audio audio("0", rtc::Description::Direction::SendRecv);
  audio.addOpusCodec(kOpusPayloadType);
  audio_track_ = peer_connection_->addTrack(std::move(audio));
  audio_rtp_config_ = std::make_shared<rtc::RtpPacketizationConfig>(
      config_.audio_ssrc, "", kOpusPayloadType, 48000);
  auto audio_packetizer =
      std::make_shared<rtc::OpusRtpPacketizer>(audio_rtp_config_);
  audio_track_->setMediaHandler(std::move(audio_packetizer));

  rtc::Description::Video video("1", rtc::Description::Direction::SendRecv);
  video.addH264Codec(kH264PayloadType);
  video.addRtxCodec(kRtxPayloadType, kH264PayloadType, kVideoClockRate);
  video_track_ = peer_connection_->addTrack(std::move(video));
  video_rtp_config_ = std::make_shared<rtc::RtpPacketizationConfig>(
      config_.video_ssrc, "", kH264PayloadType, kVideoClockRate);
  auto video_packetizer = std::make_shared<rtc::H264RtpPacketizer>(
      rtc::NalUnit::Separator::StartSequence, video_rtp_config_);
  video_track_->setMediaHandler(std::move(video_packetizer));
}

}  // namespace flutter_webrtc_plugin
