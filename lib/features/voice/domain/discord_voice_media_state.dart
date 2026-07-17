enum DiscordVoiceMediaPhase { idle, starting, active, stopping, failed }

enum DiscordVoiceInputMode { voiceActivity, pushToTalk }

final class DiscordVoiceMediaState {
  const DiscordVoiceMediaState({
    this.phase = DiscordVoiceMediaPhase.idle,
    this.muted = false,
    this.deafened = false,
    this.speaking = false,
    this.inputMode = DiscordVoiceInputMode.voiceActivity,
    this.pushToTalkPressed = false,
    this.remoteVideoPreviews = const {},
    this.errorMessage,
  });

  final DiscordVoiceMediaPhase phase;
  final bool muted;
  final bool deafened;
  final bool speaking;
  final DiscordVoiceInputMode inputMode;
  final bool pushToTalkPressed;
  final Map<String, Object> remoteVideoPreviews;
  final String? errorMessage;

  DiscordVoiceMediaState copyWith({
    DiscordVoiceMediaPhase? phase,
    bool? muted,
    bool? deafened,
    bool? speaking,
    DiscordVoiceInputMode? inputMode,
    bool? pushToTalkPressed,
    Map<String, Object>? remoteVideoPreviews,
    Object? errorMessage = _unset,
  }) {
    return DiscordVoiceMediaState(
      phase: phase ?? this.phase,
      muted: muted ?? this.muted,
      deafened: deafened ?? this.deafened,
      speaking: speaking ?? this.speaking,
      inputMode: inputMode ?? this.inputMode,
      pushToTalkPressed: pushToTalkPressed ?? this.pushToTalkPressed,
      remoteVideoPreviews: remoteVideoPreviews ?? this.remoteVideoPreviews,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();
