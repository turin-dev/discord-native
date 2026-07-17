const Duration discordTypingDuration = Duration(seconds: 10);

final class DiscordTypingUser {
  const DiscordTypingUser({
    required this.channelId,
    required this.userId,
    required this.displayName,
    required this.expiresAt,
  });

  static DiscordTypingUser? fromPayload(
    Map<String, Object?> payload, {
    required DateTime now,
    required String? currentUserId,
  }) {
    if (payload['op'] != 0 || payload['t'] != 'TYPING_START') {
      return null;
    }
    final data = _readMap(payload['d'], 'typing dispatch data');
    final channelId = _requiredString(data['channel_id'], 'typing.channel_id');
    final userId = _requiredString(data['user_id'], 'typing.user_id');
    if (userId == currentUserId) {
      return null;
    }
    final member = _optionalMap(data['member']);
    final user = _optionalMap(member?['user']);
    final displayName =
        _optionalString(member?['nick']) ??
        _optionalString(user?['global_name']) ??
        _optionalString(user?['username']) ??
        userId;
    return DiscordTypingUser(
      channelId: channelId,
      userId: userId,
      displayName: displayName,
      expiresAt: now.add(discordTypingDuration),
    );
  }

  final String channelId;
  final String userId;
  final String displayName;
  final DateTime expiresAt;
}

final class DiscordTypingState {
  const DiscordTypingState() : _usersByChannel = const {};

  const DiscordTypingState._(this._usersByChannel);

  final Map<String, List<DiscordTypingUser>> _usersByChannel;

  List<DiscordTypingUser> usersForChannel(String? channelId) {
    if (channelId == null) {
      return const [];
    }
    return _usersByChannel[channelId] ?? const [];
  }

  DiscordTypingState payloadReceived(
    Map<String, Object?> payload, {
    required DateTime now,
    required String? currentUserId,
  }) {
    final typingUser = DiscordTypingUser.fromPayload(
      payload,
      now: now,
      currentUserId: currentUserId,
    );
    if (typingUser != null) {
      return _upsert(typingUser);
    }
    if (payload['op'] != 0 || payload['t'] != 'MESSAGE_CREATE') {
      return this;
    }
    final data = _readMap(payload['d'], 'message dispatch data');
    final channelId = _requiredString(data['channel_id'], 'message.channel_id');
    final author = _readMap(data['author'], 'message.author');
    final userId = _requiredString(author['id'], 'message.author.id');
    return remove(channelId, userId);
  }

  DiscordTypingState expire(
    String channelId,
    String userId,
    DateTime expectedExpiresAt,
  ) {
    for (final user in usersForChannel(channelId)) {
      if (user.userId == userId && user.expiresAt.isAfter(expectedExpiresAt)) {
        return this;
      }
    }
    return remove(channelId, userId);
  }

  DiscordTypingState remove(String channelId, String userId) {
    final current = usersForChannel(channelId);
    final nextUsers = current.where((user) => user.userId != userId).toList();
    if (nextUsers.length == current.length) {
      return this;
    }
    final Map<String, List<DiscordTypingUser>> nextByChannel = {
      for (final entry in _usersByChannel.entries)
        if (entry.key != channelId) entry.key: entry.value,
      if (nextUsers.isNotEmpty)
        channelId: List<DiscordTypingUser>.unmodifiable(nextUsers),
    };
    return DiscordTypingState._(
      Map<String, List<DiscordTypingUser>>.unmodifiable(nextByChannel),
    );
  }

  DiscordTypingState _upsert(DiscordTypingUser nextUser) {
    final List<DiscordTypingUser> nextUsers = [
      for (final user in usersForChannel(nextUser.channelId))
        if (user.userId != nextUser.userId) user,
      nextUser,
    ];
    final Map<String, List<DiscordTypingUser>> nextByChannel = {
      ..._usersByChannel,
      nextUser.channelId: List<DiscordTypingUser>.unmodifiable(nextUsers),
    };
    return DiscordTypingState._(
      Map<String, List<DiscordTypingUser>>.unmodifiable(nextByChannel),
    );
  }
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value == null) {
    return null;
  }
  return _readMap(value, 'optional object');
}

String _requiredString(Object? value, String field) {
  final string = _optionalString(value);
  if (string == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return string;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}
