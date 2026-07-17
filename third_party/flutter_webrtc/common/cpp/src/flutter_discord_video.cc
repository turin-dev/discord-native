#include "flutter_discord_video.h"

#include <cstdint>
#include <limits>
#include <stdexcept>
#include <utility>

#include "flutter_webrtc_base.h"

namespace flutter_webrtc_plugin {

namespace {

uint32_t RequiredSsrc(const EncodableMap& params, const std::string& field) {
  const int64_t value = findLongInt(params, field);
  if (value < 0 ||
      static_cast<uint64_t>(value) >
          (std::numeric_limits<uint32_t>::max)()) {
    throw std::invalid_argument(field + " must be an unsigned 32-bit integer");
  }
  return static_cast<uint32_t>(value);
}

int RequiredPositiveInt(const EncodableMap& params,
                        const std::string& field,
                        int maximum) {
  const int64_t value = findLongInt(params, field);
  if (value < 1 || value > maximum) {
    throw std::invalid_argument(field + " is outside the supported range");
  }
  return static_cast<int>(value);
}

std::string RequiredString(const EncodableMap& params,
                           const std::string& field) {
  const std::string value = findString(params, field);
  if (value.empty()) {
    throw std::invalid_argument(field + " is required");
  }
  return value;
}

}  // namespace

FlutterDiscordVideo::FlutterDiscordVideo(FlutterWebRTCBase* base)
    : base_(base),
      event_channel_(EventChannelProxy::Create(
          base->binary_messenger(), base->task_runner(),
          "DiscordNativeRTC.Event")) {}

FlutterDiscordVideo::~FlutterDiscordVideo() = default;

void FlutterDiscordVideo::HandleDiscordVideoMethod(
    const MethodCallProxy& method_call,
    std::unique_ptr<MethodResultProxy> result) {
  try {
    if (!method_call.arguments()) {
      throw std::invalid_argument("Discord video arguments are required");
    }
    const EncodableMap params =
        GetValue<EncodableMap>(*method_call.arguments());
    const std::string& method = method_call.method_name();
    if (method == "discordVideoCreateSession") {
      CreateSession(params, result.get());
    } else if (method == "discordVideoAcceptAnswer") {
      AcceptAnswer(params, result.get());
    } else if (method == "discordVideoSendAudio") {
      SendAudio(params, result.get());
    } else if (method == "discordVideoSendFrame") {
      SendVideo(params, result.get());
    } else if (method == "discordVideoRenderFrame") {
      RenderVideo(params, result.get());
    } else if (method == "discordVideoCloseSession") {
      CloseSession(params, result.get());
    } else {
      result->NotImplemented();
    }
  } catch (const std::exception& error) {
    result->Error("discordVideoFailed", error.what());
  }
}

void FlutterDiscordVideo::CreateSession(
    const EncodableMap& params,
    MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  if (transports_.find(session_id) != transports_.end()) {
    throw std::logic_error("Discord video session already exists");
  }
  DiscordVideoSessionConfig config{
      RequiredSsrc(params, "audioSsrc"),
      RequiredSsrc(params, "videoSsrc"),
      RequiredSsrc(params, "rtxSsrc"),
      RequiredString(params, "sourceKind"),
      RequiredString(params, "sourceId"),
      RequiredPositiveInt(params, "width", 3840),
      RequiredPositiveInt(params, "height", 2160),
      RequiredPositiveInt(params, "framesPerSecond", 60),
  };
  if (config.source_kind != "camera" && config.source_kind != "screen" &&
      config.source_kind != "receive") {
    throw std::invalid_argument("Unsupported Discord video source kind");
  }
  auto transport = std::make_unique<DiscordVideoTransport>(
      std::move(config),
      [this, session_id](uint32_t ssrc, uint16_t sequence,
                         std::vector<uint8_t> frame) {
        EmitAudioFrame(session_id, ssrc, sequence, std::move(frame));
      },
      [this, session_id](uint32_t ssrc, uint32_t timestamp,
                         std::vector<uint8_t> frame) {
        EmitVideoFrame(session_id, ssrc, timestamp, std::move(frame));
      });
  const std::string offer = transport->CreateOffer();
  transports_.emplace(session_id, std::move(transport));
  result->Success(EncodableValue(offer));
}

void FlutterDiscordVideo::AcceptAnswer(
    const EncodableMap& params,
    MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  const auto transport = transports_.find(session_id);
  if (transport == transports_.end()) {
    throw std::logic_error("Discord video session does not exist");
  }
  const int64_t dave_address = findLongInt(params, "daveEncryptorAddress");
  if (dave_address <= 0) {
    throw std::invalid_argument("DAVE encryptor address is required");
  }
  transport->second->AcceptAnswer(
      RequiredString(params, "sdp"), RequiredString(params, "videoCodec"),
      static_cast<uintptr_t>(dave_address));
  const auto& config = transport->second->config();
  if (config.source_kind == "receive") {
    ready_sessions_.insert(session_id);
    result->Success();
    return;
  }
  const auto media_track = base_->MediaTrackForId(config.source_id);
  if (!media_track || media_track->kind().std_string() != "video") {
    throw std::logic_error("Discord video source track does not exist");
  }
  auto* video_track =
      dynamic_cast<libwebrtc::RTCVideoTrack*>(media_track.get());
  if (video_track == nullptr) {
    throw std::logic_error("Discord video source is not a video track");
  }
  auto encoder = std::make_unique<DiscordH264CaptureEncoder>(
      libwebrtc::scoped_refptr<libwebrtc::RTCVideoTrack>(video_track),
      config.frames_per_second,
      [video_transport = transport->second.get()](std::vector<uint8_t> frame,
                                                   int duration) {
        video_transport->SendVideoFrame(frame, duration);
      },
      [this, session_id](std::string message) {
        EmitVideoError(session_id, message);
      });
  encoder->Start();
  encoders_.emplace(session_id, std::move(encoder));
  ready_sessions_.insert(session_id);
  result->Success();
}

void FlutterDiscordVideo::SendAudio(const EncodableMap& params,
                                    MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  const auto transport = transports_.find(session_id);
  if (transport == transports_.end()) {
    throw std::logic_error("Discord video session does not exist");
  }
  const std::vector<uint8_t> frame = findVector(params, "frame");
  if (frame.empty()) {
    throw std::invalid_argument("Opus frame is required");
  }
  transport->second->SendAudioFrame(
      frame, RequiredPositiveInt(params, "durationMilliseconds", 60));
  result->Success();
}

void FlutterDiscordVideo::SendVideo(const EncodableMap& params,
                                    MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  const auto transport = transports_.find(session_id);
  if (transport == transports_.end()) {
    throw std::logic_error("Discord video session does not exist");
  }
  const std::vector<uint8_t> frame = findVector(params, "frame");
  if (frame.empty()) {
    throw std::invalid_argument("H264 frame is required");
  }
  transport->second->SendVideoFrame(
      frame, RequiredPositiveInt(params, "durationMilliseconds", 1000));
  result->Success();
}

void FlutterDiscordVideo::RenderVideo(const EncodableMap& params,
                                      MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  if (transports_.find(session_id) == transports_.end() ||
      ready_sessions_.find(session_id) == ready_sessions_.end()) {
    throw std::logic_error("Discord video session is not ready");
  }
  const std::string stream_id = RequiredString(params, "renderStreamId");
  const uint32_t ssrc = RequiredSsrc(params, "ssrc");
  const uint32_t timestamp = RequiredSsrc(params, "timestamp");
  std::vector<uint8_t> frame = findVector(params, "frame");
  if (frame.empty()) {
    throw std::invalid_argument("H264 render frame is required");
  }

  auto& session_renderers = remote_renderers_[session_id];
  auto renderer = session_renderers.find(ssrc);
  if (renderer == session_renderers.end()) {
    const auto stream = base_->MediaStreamForId(stream_id, "local");
    if (!stream) {
      throw std::logic_error("Discord video render stream does not exist");
    }
    const auto source = base_->factory_->CreateCustomVideoSource(
        "discord_remote_video", base_->ParseMediaConstraints(EncodableMap{}));
    if (!source) {
      throw std::runtime_error("Failed to create Discord video render source");
    }
    const std::string track_id = base_->GenerateUUID();
    const auto track =
        base_->factory_->CreateVideoTrack(source, track_id.c_str());
    if (!track || !stream->AddTrack(track)) {
      throw std::runtime_error("Failed to attach Discord video render track");
    }
    auto decoder = std::make_unique<DiscordH264RenderDecoder>(
        source, [this, session_id](std::string message) {
          EmitVideoError(session_id, message);
        });
    try {
      decoder->Start();
    } catch (...) {
      stream->RemoveTrack(track);
      throw;
    }
    base_->local_tracks_[track_id] = track;
    auto remote_renderer = std::make_unique<RemoteVideoRenderer>(
        RemoteVideoRenderer{stream_id, stream, track, std::move(decoder)});
    renderer = session_renderers
                   .emplace(ssrc, std::move(remote_renderer))
                   .first;
  } else if (renderer->second->stream_id != stream_id) {
    throw std::logic_error("Discord video SSRC render stream changed");
  }
  renderer->second->decoder->Decode(std::move(frame), timestamp);
  result->Success();
}

void FlutterDiscordVideo::CloseSession(
    const EncodableMap& params,
    MethodResultProxy* result) {
  const std::string session_id = RequiredString(params, "sessionId");
  const auto transport = transports_.find(session_id);
  if (transport == transports_.end()) {
    throw std::logic_error("Discord video session does not exist");
  }
  RemoveRemoteRenderers(session_id);
  encoders_.erase(session_id);
  ready_sessions_.erase(session_id);
  transports_.erase(transport);
  result->Success();
}

void FlutterDiscordVideo::RemoveRemoteRenderers(
    const std::string& session_id) {
  const auto session = remote_renderers_.find(session_id);
  if (session == remote_renderers_.end()) {
    return;
  }
  for (auto& entry : session->second) {
    auto& renderer = entry.second;
    renderer->decoder.reset();
    renderer->stream->RemoveTrack(renderer->track);
    base_->local_tracks_.erase(renderer->track->id().std_string());
  }
  remote_renderers_.erase(session);
}

void FlutterDiscordVideo::EmitAudioFrame(const std::string& session_id,
                                         uint32_t ssrc,
                                         uint16_t sequence,
                                         std::vector<uint8_t> frame) {
  EncodableMap event;
  event[EncodableValue("event")] = EncodableValue("discordAudioFrame");
  event[EncodableValue("sessionId")] = EncodableValue(session_id);
  event[EncodableValue("ssrc")] = EncodableValue(static_cast<int64_t>(ssrc));
  event[EncodableValue("sequence")] =
      EncodableValue(static_cast<int32_t>(sequence));
  event[EncodableValue("frame")] = EncodableValue(std::move(frame));
  event_channel_->Success(EncodableValue(std::move(event)), false);
}

void FlutterDiscordVideo::EmitVideoFrame(const std::string& session_id,
                                         uint32_t ssrc,
                                         uint32_t timestamp,
                                         std::vector<uint8_t> frame) {
  EncodableMap event;
  event[EncodableValue("event")] = EncodableValue("discordVideoFrame");
  event[EncodableValue("sessionId")] = EncodableValue(session_id);
  event[EncodableValue("ssrc")] = EncodableValue(static_cast<int64_t>(ssrc));
  event[EncodableValue("timestamp")] =
      EncodableValue(static_cast<int64_t>(timestamp));
  event[EncodableValue("frame")] = EncodableValue(std::move(frame));
  event_channel_->Success(EncodableValue(std::move(event)), false);
}

void FlutterDiscordVideo::EmitVideoError(const std::string& session_id,
                                         const std::string& message) {
  EncodableMap event;
  event[EncodableValue("event")] = EncodableValue("discordVideoError");
  event[EncodableValue("sessionId")] = EncodableValue(session_id);
  event[EncodableValue("message")] = EncodableValue(message);
  event_channel_->Success(EncodableValue(std::move(event)), false);
}

}  // namespace flutter_webrtc_plugin
