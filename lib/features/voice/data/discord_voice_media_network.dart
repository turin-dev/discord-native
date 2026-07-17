import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';

final class DiscordVoiceMediaSession {
  DiscordVoiceMediaSession({
    required this.ssrc,
    required String encryptionMode,
    required Uint8List secretKey,
  }) : _encryptionMode = encryptionMode,
       _secretKey = Uint8List.fromList(secretKey),
       usesWebRtc = false {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('Voice media SSRC 범위가 올바르지 않습니다.');
    }
    if (encryptionMode.trim().isEmpty) {
      throw const FormatException('Voice media encryption mode가 필요합니다.');
    }
    if (secretKey.length != 32) {
      throw const FormatException('Voice media secret key는 32바이트여야 합니다.');
    }
  }

  DiscordVoiceMediaSession.webRtc({required this.ssrc})
    : _encryptionMode = null,
      _secretKey = null,
      usesWebRtc = true {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('Voice media SSRC 범위가 올바르지 않습니다.');
    }
  }

  final int ssrc;
  final bool usesWebRtc;
  final String? _encryptionMode;
  final Uint8List? _secretKey;

  String get encryptionMode {
    final mode = _encryptionMode;
    if (mode == null) {
      throw StateError('WebRTC media session에는 UDP encryption mode가 없습니다.');
    }
    return mode;
  }

  Uint8List get secretKey {
    final key = _secretKey;
    if (key == null) {
      throw StateError('WebRTC media session에는 UDP secret key가 없습니다.');
    }
    return Uint8List.fromList(key);
  }
}

abstract interface class DiscordVoiceMediaNetwork {
  DiscordVoiceMediaSession get session;

  Stream<Uint8List> get udpPackets;

  Stream<DiscordVoiceRtcAudioFrame> get rtcAudioFrames;

  Stream<DiscordVoiceRtcVideoFrame> get rtcVideoFrames;

  Stream<DiscordVoiceRtcVideoStream> get rtcVideoStreams;

  Map<int, String> get usersBySsrc;

  Stream<Map<int, String>> get usersBySsrcChanges;

  Map<int, String> get videoUsersBySsrc;

  Stream<Map<int, String>> get videoUsersBySsrcChanges;

  Future<void> sendUdp(Uint8List packet);

  Future<void> sendRtcAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  });

  Future<void> renderRtcVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  });

  Future<void> setSpeaking(bool speaking);

  Uint8List protectAudio(Uint8List opusFrame);

  Uint8List unprotectAudio(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  });

  Uint8List unprotectVideo(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  });
}

final class DiscordVoiceGatewayMediaNetwork
    implements DiscordVoiceMediaNetwork {
  const DiscordVoiceGatewayMediaNetwork(this._client);

  final DiscordVoiceGatewayClient _client;

  @override
  DiscordVoiceMediaSession get session {
    final state = _client.state;
    final ssrc = state.ssrc;
    final mode = state.encryptionMode;
    final secretKey = state.secretKey;
    if ((state.phase != DiscordVoiceNetworkPhase.ready &&
            state.phase != DiscordVoiceNetworkPhase.resuming) ||
        ssrc == null) {
      throw StateError('Voice media session이 준비되지 않았습니다.');
    }
    if (_client.usesWebRtc) {
      return DiscordVoiceMediaSession.webRtc(ssrc: ssrc);
    }
    if (mode == null || secretKey == null) {
      throw StateError('Voice UDP media session이 준비되지 않았습니다.');
    }
    return DiscordVoiceMediaSession(
      ssrc: ssrc,
      encryptionMode: mode,
      secretKey: secretKey,
    );
  }

  @override
  Stream<Uint8List> get udpPackets => _client.udpPackets;

  @override
  Stream<DiscordVoiceRtcAudioFrame> get rtcAudioFrames =>
      _client.rtcAudioFrames;

  @override
  Stream<DiscordVoiceRtcVideoFrame> get rtcVideoFrames =>
      _client.rtcVideoFrames;

  @override
  Stream<DiscordVoiceRtcVideoStream> get rtcVideoStreams =>
      _client.rtcVideoStreams;

  @override
  Map<int, String> get usersBySsrc => _client.state.usersBySsrc;

  @override
  Stream<Map<int, String>> get usersBySsrcChanges {
    return _client.states.map((state) => state.usersBySsrc);
  }

  @override
  Map<int, String> get videoUsersBySsrc => _client.state.videoUsersBySsrc;

  @override
  Stream<Map<int, String>> get videoUsersBySsrcChanges {
    return _client.states.map((state) => state.videoUsersBySsrc);
  }

  @override
  Future<void> sendUdp(Uint8List packet) => _client.sendUdp(packet);

  @override
  Future<void> sendRtcAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) {
    return _client.sendRtcAudio(
      opusFrame,
      durationMilliseconds: durationMilliseconds,
    );
  }

  @override
  Future<void> renderRtcVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) {
    return _client.renderRtcVideo(
      h264AccessUnit,
      ssrc: ssrc,
      timestamp: timestamp,
    );
  }

  @override
  Future<void> setSpeaking(bool speaking) => _client.setSpeaking(speaking);

  @override
  Uint8List protectAudio(Uint8List opusFrame) {
    return _client.protectAudio(opusFrame);
  }

  @override
  Uint8List unprotectAudio(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    return _client.unprotectAudio(encryptedFrame, remoteUserId: remoteUserId);
  }

  @override
  Uint8List unprotectVideo(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    return _client.unprotectVideo(encryptedFrame, remoteUserId: remoteUserId);
  }
}
