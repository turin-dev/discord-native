#ifndef FLUTTER_WEBRTC_FLUTTER_DISCORD_VIDEO_H_
#define FLUTTER_WEBRTC_FLUTTER_DISCORD_VIDEO_H_

#include <map>
#include <memory>
#include <set>
#include <string>

#include "discord_h264_capture_encoder.h"
#include "discord_h264_render_decoder.h"
#include "discord_video_transport.h"
#include "flutter_common.h"
#include "rtc_media_stream.h"
#include "rtc_video_track.h"

namespace flutter_webrtc_plugin {

class FlutterWebRTCBase;

class FlutterDiscordVideo {
 public:
  explicit FlutterDiscordVideo(FlutterWebRTCBase* base);
  virtual ~FlutterDiscordVideo();

  void HandleDiscordVideoMethod(
      const MethodCallProxy& method_call,
      std::unique_ptr<MethodResultProxy> result);

 private:
  struct RemoteVideoRenderer {
    std::string stream_id;
    libwebrtc::scoped_refptr<libwebrtc::RTCMediaStream> stream;
    libwebrtc::scoped_refptr<libwebrtc::RTCVideoTrack> track;
    std::unique_ptr<DiscordH264RenderDecoder> decoder;
  };

  void CreateSession(const EncodableMap& params, MethodResultProxy* result);
  void AcceptAnswer(const EncodableMap& params, MethodResultProxy* result);
  void SendAudio(const EncodableMap& params, MethodResultProxy* result);
  void SendVideo(const EncodableMap& params, MethodResultProxy* result);
  void RenderVideo(const EncodableMap& params, MethodResultProxy* result);
  void CloseSession(const EncodableMap& params, MethodResultProxy* result);
  void RemoveRemoteRenderers(const std::string& session_id);
  void EmitAudioFrame(const std::string& session_id,
                      uint32_t ssrc,
                      uint16_t sequence,
                      std::vector<uint8_t> frame);
  void EmitVideoFrame(const std::string& session_id,
                      uint32_t ssrc,
                      uint32_t timestamp,
                      std::vector<uint8_t> frame);
  void EmitVideoError(const std::string& session_id,
                      const std::string& message);

  FlutterWebRTCBase* base_;
  std::unique_ptr<EventChannelProxy> event_channel_;
  std::map<std::string, std::unique_ptr<DiscordVideoTransport>> transports_;
  std::map<std::string, std::unique_ptr<DiscordH264CaptureEncoder>> encoders_;
  std::set<std::string> ready_sessions_;
  std::map<std::string,
           std::map<uint32_t, std::unique_ptr<RemoteVideoRenderer>>>
      remote_renderers_;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_FLUTTER_DISCORD_VIDEO_H_
