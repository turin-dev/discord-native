import 'package:discord_native/features/video/domain/discord_video_protocol.dart';

enum DiscordVideoPhase { idle, starting, active, stopping, failed }

final class DiscordVideoUiState {
  const DiscordVideoUiState({
    this.phase = DiscordVideoPhase.idle,
    this.sourceKind,
    this.remotePreviews = const {},
    this.screenSharePhase = DiscordVideoPhase.idle,
    this.screenStreamKey,
    this.screenPaused = false,
    this.watchingStreamKey,
    this.errorMessage,
  });

  final DiscordVideoPhase phase;
  final DiscordVideoSourceKind? sourceKind;
  final Map<String, Object> remotePreviews;
  final DiscordVideoPhase screenSharePhase;
  final String? screenStreamKey;
  final bool screenPaused;
  final String? watchingStreamKey;
  final String? errorMessage;

  bool get cameraEnabled {
    return phase == DiscordVideoPhase.active &&
        sourceKind == DiscordVideoSourceKind.camera;
  }

  bool get screenShareEnabled {
    return screenSharePhase == DiscordVideoPhase.active &&
        screenStreamKey != null;
  }

  DiscordVideoUiState copyWith({
    DiscordVideoPhase? phase,
    Object? sourceKind = _unset,
    Map<String, Object>? remotePreviews,
    DiscordVideoPhase? screenSharePhase,
    Object? screenStreamKey = _unset,
    bool? screenPaused,
    Object? watchingStreamKey = _unset,
    Object? errorMessage = _unset,
  }) {
    return DiscordVideoUiState(
      phase: phase ?? this.phase,
      sourceKind: identical(sourceKind, _unset)
          ? this.sourceKind
          : sourceKind as DiscordVideoSourceKind?,
      remotePreviews: remotePreviews ?? this.remotePreviews,
      screenSharePhase: screenSharePhase ?? this.screenSharePhase,
      screenStreamKey: identical(screenStreamKey, _unset)
          ? this.screenStreamKey
          : screenStreamKey as String?,
      screenPaused: screenPaused ?? this.screenPaused,
      watchingStreamKey: identical(watchingStreamKey, _unset)
          ? this.watchingStreamKey
          : watchingStreamKey as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();
