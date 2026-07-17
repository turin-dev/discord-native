import 'dart:typed_data';

import 'package:discord_native/features/video/domain/discord_video_protocol.dart';

enum DiscordVoiceNetworkPhase {
  disconnected,
  connecting,
  identifying,
  discoveringUdp,
  selectingProtocol,
  ready,
  resuming,
  failed,
}

final class DiscordVoiceNetworkState {
  DiscordVoiceNetworkState({
    this.phase = DiscordVoiceNetworkPhase.disconnected,
    this.sequence = -1,
    this.awaitingHeartbeatAck = false,
    this.ssrc,
    this.encryptionMode,
    this.secretKey,
    this.daveProtocolVersion,
    this.videoSsrc,
    this.rtxSsrc,
    this.videoCodec,
    Map<int, String> usersBySsrc = const {},
    Map<int, String> videoUsersBySsrc = const {},
    this.errorMessage,
  }) : usersBySsrc = Map.unmodifiable(usersBySsrc),
       videoUsersBySsrc = Map.unmodifiable(videoUsersBySsrc);

  final DiscordVoiceNetworkPhase phase;
  final int sequence;
  final bool awaitingHeartbeatAck;
  final int? ssrc;
  final String? encryptionMode;
  final Uint8List? secretKey;
  final int? daveProtocolVersion;
  final int? videoSsrc;
  final int? rtxSsrc;
  final DiscordVideoCodec? videoCodec;
  final Map<int, String> usersBySsrc;
  final Map<int, String> videoUsersBySsrc;
  final String? errorMessage;

  DiscordVoiceNetworkState copyWith({
    DiscordVoiceNetworkPhase? phase,
    int? sequence,
    bool? awaitingHeartbeatAck,
    Object? ssrc = _unset,
    Object? encryptionMode = _unset,
    Object? secretKey = _unset,
    Object? daveProtocolVersion = _unset,
    Object? videoSsrc = _unset,
    Object? rtxSsrc = _unset,
    Object? videoCodec = _unset,
    Map<int, String>? usersBySsrc,
    Map<int, String>? videoUsersBySsrc,
    Object? errorMessage = _unset,
  }) {
    return DiscordVoiceNetworkState(
      phase: phase ?? this.phase,
      sequence: sequence ?? this.sequence,
      awaitingHeartbeatAck: awaitingHeartbeatAck ?? this.awaitingHeartbeatAck,
      ssrc: identical(ssrc, _unset) ? this.ssrc : ssrc as int?,
      encryptionMode: identical(encryptionMode, _unset)
          ? this.encryptionMode
          : encryptionMode as String?,
      secretKey: identical(secretKey, _unset)
          ? this.secretKey
          : secretKey as Uint8List?,
      daveProtocolVersion: identical(daveProtocolVersion, _unset)
          ? this.daveProtocolVersion
          : daveProtocolVersion as int?,
      videoSsrc: identical(videoSsrc, _unset)
          ? this.videoSsrc
          : videoSsrc as int?,
      rtxSsrc: identical(rtxSsrc, _unset) ? this.rtxSsrc : rtxSsrc as int?,
      videoCodec: identical(videoCodec, _unset)
          ? this.videoCodec
          : videoCodec as DiscordVideoCodec?,
      usersBySsrc: usersBySsrc ?? this.usersBySsrc,
      videoUsersBySsrc: videoUsersBySsrc ?? this.videoUsersBySsrc,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();
