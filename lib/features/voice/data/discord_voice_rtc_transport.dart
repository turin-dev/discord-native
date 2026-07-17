import 'dart:typed_data';

import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';

final class DiscordVoiceRtcAnswer {
  const DiscordVoiceRtcAnswer({
    required this.sdp,
    required this.audioCodec,
    required this.videoCodec,
    required this.daveSession,
  });

  final String sdp;
  final String audioCodec;
  final DiscordVideoCodec videoCodec;
  final DiscordDaveSession daveSession;
}

abstract interface class DiscordVoiceRtcTransport {
  Future<DiscordVoiceRtcOffer> createOffer(DiscordVoiceRtcSession session);

  Future<void> acceptAnswer(DiscordVoiceRtcAnswer answer);

  Future<void> close();
}

final class DiscordVoiceRtcAudioFrame {
  DiscordVoiceRtcAudioFrame({
    required this.ssrc,
    required this.sequence,
    required Uint8List encryptedOpus,
  }) : _encryptedOpus = Uint8List.fromList(encryptedOpus) {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('WebRTC audio SSRC 범위가 올바르지 않습니다.');
    }
    if (sequence < 0 || sequence > 0xFFFF) {
      throw const FormatException('WebRTC audio sequence 범위가 올바르지 않습니다.');
    }
    if (encryptedOpus.isEmpty) {
      throw const FormatException('WebRTC audio frame이 비어 있습니다.');
    }
  }

  final int ssrc;
  final int sequence;
  final Uint8List _encryptedOpus;

  Uint8List get encryptedOpus => Uint8List.fromList(_encryptedOpus);
}

final class DiscordVoiceRtcVideoFrame {
  DiscordVoiceRtcVideoFrame({
    required this.ssrc,
    required this.timestamp,
    required Uint8List encryptedH264,
  }) : _encryptedH264 = Uint8List.fromList(encryptedH264) {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('WebRTC video SSRC 범위가 올바르지 않습니다.');
    }
    if (timestamp < 0 || timestamp > 0xFFFFFFFF) {
      throw const FormatException('WebRTC video timestamp 범위가 올바르지 않습니다.');
    }
    if (encryptedH264.isEmpty) {
      throw const FormatException('WebRTC video frame이 비어 있습니다.');
    }
  }

  final int ssrc;
  final int timestamp;
  final Uint8List _encryptedH264;

  Uint8List get encryptedH264 => Uint8List.fromList(_encryptedH264);
}

final class DiscordVoiceRtcVideoStream {
  DiscordVoiceRtcVideoStream({required this.ssrc, required this.preview}) {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('WebRTC video stream SSRC 범위가 올바르지 않습니다.');
    }
  }

  final int ssrc;
  final Object preview;
}

abstract interface class DiscordVoiceRtcMediaTransport
    implements DiscordVoiceRtcTransport {
  Stream<String> get errors;

  Stream<DiscordVoiceRtcAudioFrame> get audioFrames;

  Stream<DiscordVoiceRtcVideoFrame> get videoFrames;

  Stream<DiscordVoiceRtcVideoStream> get videoStreams;

  Future<void> sendAudio(Uint8List opusFrame, {int durationMilliseconds = 20});

  Future<void> sendVideo(
    Uint8List h264AccessUnit, {
    required int durationMilliseconds,
  });

  Future<void> renderVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  });
}
