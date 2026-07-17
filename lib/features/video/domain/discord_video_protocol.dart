enum DiscordVideoCodec {
  h264('H264');

  const DiscordVideoCodec(this.gatewayName);

  final String gatewayName;

  static DiscordVideoCodec parse(String value) {
    final normalized = value.trim().toUpperCase();
    return values.firstWhere(
      (codec) => codec.gatewayName == normalized,
      orElse: () =>
          throw FormatException('지원하지 않는 Discord video codec입니다: $value'),
    );
  }
}

abstract final class DiscordVideoCodecCapabilities {
  static const List<Map<String, Object>> gatewayPayload = [
    {'name': 'opus', 'type': 'audio', 'priority': 1000, 'payload_type': 120},
    {
      'name': 'H264',
      'type': 'video',
      'priority': 1000,
      'payload_type': 101,
      'rtx_payload_type': 102,
      'encode': true,
      'decode': true,
    },
  ];
}

enum DiscordVideoSourceKind { camera, screen }

final class DiscordVideoSource {
  const DiscordVideoSource.camera({
    required this.sourceId,
    required this.width,
    required this.height,
    required this.framesPerSecond,
  }) : kind = DiscordVideoSourceKind.camera;

  const DiscordVideoSource.screen({
    required this.sourceId,
    required this.width,
    required this.height,
    required this.framesPerSecond,
  }) : kind = DiscordVideoSourceKind.screen;

  final DiscordVideoSourceKind kind;
  final String sourceId;
  final int width;
  final int height;
  final int framesPerSecond;

  @override
  bool operator ==(Object other) {
    return other is DiscordVideoSource &&
        kind == other.kind &&
        sourceId == other.sourceId &&
        width == other.width &&
        height == other.height &&
        framesPerSecond == other.framesPerSecond;
  }

  @override
  int get hashCode {
    return Object.hash(kind, sourceId, width, height, framesPerSecond);
  }
}

enum DiscordVoiceVideoMode { none, send, receive }

final class DiscordVoiceConnectionOptions {
  const DiscordVoiceConnectionOptions.audioOnly()
    : videoMode = DiscordVoiceVideoMode.none,
      videoSource = null;

  const DiscordVoiceConnectionOptions.video(DiscordVideoSource source)
    : videoMode = DiscordVoiceVideoMode.send,
      videoSource = source;

  const DiscordVoiceConnectionOptions.receiveVideo()
    : videoMode = DiscordVoiceVideoMode.receive,
      videoSource = null;

  final DiscordVoiceVideoMode videoMode;
  final DiscordVideoSource? videoSource;

  bool get usesWebRtc => videoMode != DiscordVoiceVideoMode.none;

  bool get sendsVideo => videoMode == DiscordVoiceVideoMode.send;
}

final class DiscordVoiceRtcSession {
  const DiscordVoiceRtcSession({
    required this.audioSsrc,
    required this.videoSsrc,
    required this.rtxSsrc,
    this.source,
  });

  final int audioSsrc;
  final int videoSsrc;
  final int rtxSsrc;
  final DiscordVideoSource? source;

  @override
  bool operator ==(Object other) {
    return other is DiscordVoiceRtcSession &&
        audioSsrc == other.audioSsrc &&
        videoSsrc == other.videoSsrc &&
        rtxSsrc == other.rtxSsrc &&
        source == other.source;
  }

  @override
  int get hashCode => Object.hash(audioSsrc, videoSsrc, rtxSsrc, source);
}

final class DiscordVoiceRtcOffer {
  const DiscordVoiceRtcOffer({
    required this.sdp,
    required this.rtcConnectionId,
  });

  final String sdp;
  final String rtcConnectionId;
}

final class DiscordVideoReadyStream {
  const DiscordVideoReadyStream({
    required this.videoSsrc,
    required this.rtxSsrc,
  });

  final int videoSsrc;
  final int rtxSsrc;

  static DiscordVideoReadyStream parse(Object? value) {
    if (value is! List || value.isEmpty || value.first is! Map) {
      throw const FormatException('Voice Ready video streams 형식이 올바르지 않습니다.');
    }
    final stream = (value.first as Map).map(
      (key, item) => MapEntry(key.toString(), item),
    );
    final videoSsrc = stream['ssrc'];
    final rtxSsrc = stream['rtx_ssrc'];
    if (videoSsrc is! int || rtxSsrc is! int) {
      throw const FormatException('Voice Ready video SSRC 형식이 올바르지 않습니다.');
    }
    _validateSsrc(videoSsrc);
    _validateSsrc(rtxSsrc);
    return DiscordVideoReadyStream(videoSsrc: videoSsrc, rtxSsrc: rtxSsrc);
  }
}

void _validateSsrc(int value) {
  if (value < 0 || value > 0xFFFFFFFF) {
    throw FormatException('Discord video SSRC 범위가 올바르지 않습니다: $value');
  }
}
