import 'package:discord_native/features/messages/domain/discord_message_state.dart';

final class DiscordMessagePin {
  const DiscordMessagePin({required this.pinnedAt, required this.message});

  final DateTime pinnedAt;
  final DiscordMessage message;
}

final class DiscordMessagePinsPage {
  DiscordMessagePinsPage({
    required List<DiscordMessagePin> pins,
    required this.hasMore,
  }) : pins = List.unmodifiable(pins);

  final List<DiscordMessagePin> pins;
  final bool hasMore;
}

final class DiscordPinnedMessagesState {
  const DiscordPinnedMessagesState({
    this.channelId,
    this.pins = const [],
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  factory DiscordPinnedMessagesState.loading(String channelId) {
    return DiscordPinnedMessagesState(channelId: channelId, isLoading: true);
  }

  factory DiscordPinnedMessagesState.loaded({
    required String channelId,
    required List<DiscordMessagePin> pins,
    required bool hasMore,
  }) {
    return DiscordPinnedMessagesState(
      channelId: channelId,
      pins: List.unmodifiable(pins),
      hasMore: hasMore,
    );
  }

  final String? channelId;
  final List<DiscordMessagePin> pins;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isOpen => channelId != null;

  DiscordPinnedMessagesState loadingMore() {
    if (!isOpen || isLoading || isLoadingMore || !hasMore) {
      return this;
    }
    return DiscordPinnedMessagesState(
      channelId: channelId,
      pins: pins,
      hasMore: hasMore,
      isLoadingMore: true,
    );
  }

  DiscordPinnedMessagesState appendPage(DiscordMessagePinsPage page) {
    final selectedChannelId = channelId;
    if (selectedChannelId == null) {
      return this;
    }
    final candidates = [...pins, ...page.pins];
    final unique = [
      for (var index = 0; index < candidates.length; index += 1)
        if (candidates.indexWhere(
              (pin) => pin.message.id == candidates[index].message.id,
            ) ==
            index)
          candidates[index],
    ];
    return DiscordPinnedMessagesState.loaded(
      channelId: selectedChannelId,
      pins: unique,
      hasMore: page.hasMore,
    );
  }

  DiscordPinnedMessagesState failed(String message) {
    return DiscordPinnedMessagesState(
      channelId: channelId,
      pins: pins,
      hasMore: hasMore,
      errorMessage: message,
    );
  }

  DiscordPinnedMessagesState removeMessage(String messageId) {
    return DiscordPinnedMessagesState(
      channelId: channelId,
      pins: List.unmodifiable(pins.where((pin) => pin.message.id != messageId)),
      hasMore: hasMore,
      errorMessage: errorMessage,
    );
  }
}
