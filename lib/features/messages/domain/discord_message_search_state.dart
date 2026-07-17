import 'package:discord_native/features/messages/domain/discord_message_state.dart';

final class DiscordMessageSearchState {
  const DiscordMessageSearchState({
    this.query = '',
    this.totalResults = 0,
    this.messages = const [],
    this.isLoading = false,
    this.currentChannelOnly = false,
    this.errorMessage,
  });

  factory DiscordMessageSearchState.loading(
    String query, {
    required bool currentChannelOnly,
  }) {
    return DiscordMessageSearchState(
      query: query,
      isLoading: true,
      currentChannelOnly: currentChannelOnly,
    );
  }

  factory DiscordMessageSearchState.loaded({
    required String query,
    required int totalResults,
    required List<DiscordMessage> messages,
    required bool currentChannelOnly,
  }) {
    return DiscordMessageSearchState(
      query: query,
      totalResults: totalResults,
      messages: List.unmodifiable(messages),
      currentChannelOnly: currentChannelOnly,
    );
  }

  final String query;
  final int totalResults;
  final List<DiscordMessage> messages;
  final bool isLoading;
  final bool currentChannelOnly;
  final String? errorMessage;

  DiscordMessageSearchState failed(String message) {
    return DiscordMessageSearchState(
      query: query,
      currentChannelOnly: currentChannelOnly,
      errorMessage: message,
    );
  }
}
