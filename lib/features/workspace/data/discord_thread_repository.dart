import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

abstract interface class ThreadRepository {
  Future<List<DiscordChannel>> listThreads({
    required String guildId,
    required String parentChannelId,
    bool includePrivateArchived = true,
  });

  Future<DiscordChannel> createPublicThread({
    required String guildId,
    required String parentChannelId,
    required String name,
  });

  Future<DiscordChannel> startThreadFromMessage({
    required String guildId,
    required String channelId,
    required String messageId,
    required String name,
  });

  Future<DiscordChannel> createForumPost({
    required String guildId,
    required String forumChannelId,
    required String title,
    required String content,
    List<String> appliedTagIds = const [],
  });

  Future<void> joinThread(String threadId);

  Future<DiscordChannel> setArchived({
    required String guildId,
    required String threadId,
    required bool archived,
  });
}

final class InvalidThreadException implements Exception {
  const InvalidThreadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordThreadRepository implements ThreadRepository {
  const DiscordThreadRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<List<DiscordChannel>> listThreads({
    required String guildId,
    required String parentChannelId,
    bool includePrivateArchived = true,
  }) async {
    final active = await _api.get('/guilds/$guildId/threads/active');
    final publicArchived = await _api.get(
      '/channels/$parentChannelId/threads/archived/public',
    );
    final privateArchived = includePrivateArchived
        ? await _api.get(
            '/channels/$parentChannelId/users/@me/threads/archived/private',
          )
        : null;
    final merged = <String, DiscordChannel>{};
    for (final envelope in [active, publicArchived, ?privateArchived]) {
      for (final channel in _readThreadEnvelope(envelope, guildId)) {
        if (channel.parentId == parentChannelId) {
          merged[channel.id] = channel;
        }
      }
    }
    final threads = merged.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return List.unmodifiable(threads);
  }

  @override
  Future<DiscordChannel> createPublicThread({
    required String guildId,
    required String parentChannelId,
    required String name,
  }) async {
    final normalized = _normalizeName(name);
    final body = await _api.post(
      '/channels/$parentChannelId/threads',
      data: {'name': normalized, 'type': 11, 'auto_archive_duration': 1440},
    );
    return _readThread(body, guildId);
  }

  @override
  Future<DiscordChannel> startThreadFromMessage({
    required String guildId,
    required String channelId,
    required String messageId,
    required String name,
  }) async {
    final normalized = _normalizeName(name);
    final body = await _api.post(
      '/channels/$channelId/messages/$messageId/threads',
      data: {'name': normalized, 'auto_archive_duration': 1440},
    );
    return _readThread(body, guildId);
  }

  @override
  Future<DiscordChannel> createForumPost({
    required String guildId,
    required String forumChannelId,
    required String title,
    required String content,
    List<String> appliedTagIds = const [],
  }) async {
    final normalizedTitle = _normalizeName(title);
    final normalizedContent = _normalizeContent(content);
    final tags = _normalizeTags(appliedTagIds);
    final body = await _api.post(
      '/channels/$forumChannelId/threads',
      data: {
        'name': normalizedTitle,
        'auto_archive_duration': 1440,
        'message': {'content': normalizedContent},
        if (tags.isNotEmpty) 'applied_tags': tags,
      },
    );
    return _readThread(body, guildId);
  }

  @override
  Future<void> joinThread(String threadId) async {
    await _api.put('/channels/$threadId/thread-members/@me');
  }

  @override
  Future<DiscordChannel> setArchived({
    required String guildId,
    required String threadId,
    required bool archived,
  }) async {
    final body = await _api.patch(
      '/channels/$threadId',
      data: {'archived': archived},
    );
    return _readThread(body, guildId);
  }
}

String _normalizeName(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) {
    throw const InvalidThreadException('스레드 이름을 입력해 주세요.');
  }
  if (normalized.length > 100) {
    throw const InvalidThreadException('스레드 이름은 100자 이하여야 합니다.');
  }
  return normalized;
}

String _normalizeContent(String content) {
  final normalized = content.trim();
  if (normalized.isEmpty) {
    throw const InvalidThreadException('포럼 본문을 입력해 주세요.');
  }
  if (normalized.length > 2000) {
    throw const InvalidThreadException('포럼 본문은 2000자 이하여야 합니다.');
  }
  return normalized;
}

List<String> _normalizeTags(List<String> tagIds) {
  final normalized = {
    for (final tagId in tagIds)
      if (tagId.trim().isNotEmpty) tagId.trim(),
  }.toList();
  if (normalized.length > 5) {
    throw const InvalidThreadException('포럼 tag는 최대 5개까지 선택할 수 있습니다.');
  }
  return List.unmodifiable(normalized);
}

List<DiscordChannel> _readThreadEnvelope(Object? value, String guildId) {
  final envelope = _readMap(value, 'thread 목록');
  final memberIds = {
    for (final item in _readList(envelope['members']))
      if (_readMap(item, 'thread member')['id'] case final String id) id,
  };
  return [
    for (final item in _readList(envelope['threads']))
      _readThread(
        item,
        guildId,
      ).copyWith(joined: memberIds.contains(_readMap(item, 'thread')['id'])),
  ];
}

DiscordChannel _readThread(Object? value, String guildId) {
  return DiscordChannel.fromJson(
    _readMap(value, 'thread'),
    fallbackGuildId: guildId,
  );
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

List<Object?> _readList(Object? value) {
  return value is List ? List.unmodifiable(value) : const [];
}
