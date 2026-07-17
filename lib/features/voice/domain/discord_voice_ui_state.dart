import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_network_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/video/domain/discord_video_ui_state.dart';

final class DiscordVoiceUiState {
  const DiscordVoiceUiState({
    this.voice = const DiscordVoiceState(),
    this.networkPhase = DiscordVoiceNetworkPhase.disconnected,
    this.media = const DiscordVoiceMediaState(),
    this.video = const DiscordVideoUiState(),
    this.errorMessage,
  });

  final DiscordVoiceState voice;
  final DiscordVoiceNetworkPhase networkPhase;
  final DiscordVoiceMediaState media;
  final DiscordVideoUiState video;
  final String? errorMessage;

  DiscordVoiceUiState copyWith({
    DiscordVoiceState? voice,
    DiscordVoiceNetworkPhase? networkPhase,
    DiscordVoiceMediaState? media,
    DiscordVideoUiState? video,
    Object? errorMessage = _unset,
  }) {
    return DiscordVoiceUiState(
      voice: voice ?? this.voice,
      networkPhase: networkPhase ?? this.networkPhase,
      media: media ?? this.media,
      video: video ?? this.video,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();
