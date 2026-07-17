import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

enum DiscordAppPhase {
  booting,
  signedOut,
  connecting,
  connected,
  reconnecting,
  failure,
}

final class DiscordAppState {
  const DiscordAppState({
    required this.phase,
    this.workspace = const DiscordWorkspaceState(),
    this.selectedGuildId,
    this.selectedChannelId,
    this.messageState = const DiscordMessageState(),
    this.typingState = const DiscordTypingState(),
    this.peopleState = const DiscordPeopleState(),
    this.peopleErrorMessage,
    this.guildErrorMessage,
    this.searchState = const DiscordMessageSearchState(),
    this.readStates = const {},
    this.voiceUiState = const DiscordVoiceUiState(),
    this.errorMessage,
  });

  const DiscordAppState.booting() : this(phase: DiscordAppPhase.booting);

  final DiscordAppPhase phase;
  final DiscordWorkspaceState workspace;
  final String? selectedGuildId;
  final String? selectedChannelId;
  final DiscordMessageState messageState;
  final DiscordTypingState typingState;
  final DiscordPeopleState peopleState;
  final String? peopleErrorMessage;
  final String? guildErrorMessage;
  final DiscordMessageSearchState searchState;
  final Map<String, DiscordReadState> readStates;
  final DiscordVoiceUiState voiceUiState;
  final String? errorMessage;

  String get connectionLabel => switch (phase) {
    DiscordAppPhase.booting => '초기화 중',
    DiscordAppPhase.signedOut => '로그아웃됨',
    DiscordAppPhase.connecting => '연결 중',
    DiscordAppPhase.connected => '연결됨',
    DiscordAppPhase.reconnecting => '재연결 중',
    DiscordAppPhase.failure => '연결 실패',
  };

  DiscordAppState copyWith({
    DiscordAppPhase? phase,
    DiscordWorkspaceState? workspace,
    Object? selectedGuildId = _unset,
    Object? selectedChannelId = _unset,
    DiscordMessageState? messageState,
    DiscordTypingState? typingState,
    DiscordPeopleState? peopleState,
    Object? peopleErrorMessage = _unset,
    Object? guildErrorMessage = _unset,
    DiscordMessageSearchState? searchState,
    Map<String, DiscordReadState>? readStates,
    DiscordVoiceUiState? voiceUiState,
    Object? errorMessage = _unset,
  }) {
    return DiscordAppState(
      phase: phase ?? this.phase,
      workspace: workspace ?? this.workspace,
      selectedGuildId: identical(selectedGuildId, _unset)
          ? this.selectedGuildId
          : selectedGuildId as String?,
      selectedChannelId: identical(selectedChannelId, _unset)
          ? this.selectedChannelId
          : selectedChannelId as String?,
      messageState: messageState ?? this.messageState,
      typingState: typingState ?? this.typingState,
      peopleState: peopleState ?? this.peopleState,
      peopleErrorMessage: identical(peopleErrorMessage, _unset)
          ? this.peopleErrorMessage
          : peopleErrorMessage as String?,
      guildErrorMessage: identical(guildErrorMessage, _unset)
          ? this.guildErrorMessage
          : guildErrorMessage as String?,
      searchState: searchState ?? this.searchState,
      readStates: Map.unmodifiable(readStates ?? this.readStates),
      voiceUiState: voiceUiState ?? this.voiceUiState,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();
