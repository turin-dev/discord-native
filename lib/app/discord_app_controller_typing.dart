part of 'discord_app_controller.dart';

extension DiscordAppControllerTyping on DiscordAppController {
  Future<void> triggerTyping() async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    final now = _now();
    final lastSentAt = _typingSentAt[channelId];
    if (lastSentAt != null && now.difference(lastSentAt) < _typingThrottle) {
      return;
    }
    _typingSentAt = Map.unmodifiable({..._typingSentAt, channelId: now});
    try {
      await repository.triggerTyping(channelId);
    } on Object catch (error) {
      if (_typingSentAt[channelId] == now) {
        _typingSentAt = Map.unmodifiable({
          for (final entry in _typingSentAt.entries)
            if (entry.key != channelId) entry.key: entry.value,
        });
      }
      _showMessageError(error);
    }
  }

  void _scheduleTypingExpiry(DiscordTypingUser user) {
    final key = '${user.channelId}:${user.userId}';
    _typingExpiryTasks[key]?.cancel();
    final remaining = user.expiresAt.difference(_now());
    final duration = remaining.isNegative ? Duration.zero : remaining;
    final task = _typingExpiryScheduler.schedule(duration, () {
      _typingExpiryTasks = Map.unmodifiable({
        for (final entry in _typingExpiryTasks.entries)
          if (entry.key != key) entry.key: entry.value,
      });
      final nextTypingState = _state.typingState.expire(
        user.channelId,
        user.userId,
        user.expiresAt,
      );
      if (!identical(nextTypingState, _state.typingState)) {
        _update(_state.copyWith(typingState: nextTypingState));
      }
    });
    _typingExpiryTasks = Map.unmodifiable({..._typingExpiryTasks, key: task});
  }

  void _clearTypingState() {
    for (final task in _typingExpiryTasks.values) {
      task.cancel();
    }
    _typingExpiryTasks = const {};
    _typingSentAt = const {};
  }
}

const Duration _typingThrottle = Duration(seconds: 8);
