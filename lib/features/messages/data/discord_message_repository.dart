import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

abstract interface class MessageRepository {
  Future<List<DiscordMessage>> fetchMessages(
    String channelId, {
    String? before,
    int limit = 50,
  });

  Future<List<DiscordMessage>> fetchMessagesAround(
    String channelId,
    String messageId, {
    int limit = 50,
  });

  Future<DiscordMessageSearchResult> searchGuildMessages(
    String guildId,
    String query, {
    String? channelId,
    int offset = 0,
  });

  Future<DiscordMessage> sendMessage(String channelId, String content);

  Future<DiscordMessage> sendStickers(
    String channelId,
    List<String> stickerIds, {
    String content = '',
  });

  Future<DiscordMessage> sendReply(
    String channelId,
    String content,
    String messageId,
  );

  Future<void> addReaction(String channelId, String messageId, String emoji);

  Future<void> removeReaction(String channelId, String messageId, String emoji);

  Future<DiscordMessage> editMessage(
    String channelId,
    String messageId,
    String content,
  );

  Future<void> deleteMessage(String channelId, String messageId);

  Future<void> setPinned(String channelId, String messageId, bool pinned);

  Future<void> triggerTyping(String channelId);

  Future<DiscordMessage> sendAttachments(
    String channelId,
    String content,
    List<DiscordUploadFile> files, {
    String? replyToMessageId,
  });
}

final class DiscordMessageSearchResult {
  const DiscordMessageSearchResult({
    required this.query,
    required this.totalResults,
    required this.messages,
    required this.threads,
  });

  final String query;
  final int totalResults;
  final List<DiscordMessage> messages;
  final List<DiscordChannel> threads;
}

final class InvalidMessageException implements Exception {
  const InvalidMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class InvalidMessageSearchException implements Exception {
  const InvalidMessageSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordMessageRepository implements MessageRepository {
  DiscordMessageRepository(
    this._api, {
    DelayCallback delay = Future<void>.delayed,
  }) : _delay = delay;

  final DiscordRestApi _api;
  final DelayCallback _delay;

  @override
  Future<List<DiscordMessage>> fetchMessages(
    String channelId, {
    String? before,
    int limit = 50,
  }) async {
    return _fetchMessages(
      channelId,
      queryParameters: {'limit': limit.clamp(1, 100), 'before': ?before},
    );
  }

  @override
  Future<List<DiscordMessage>> fetchMessagesAround(
    String channelId,
    String messageId, {
    int limit = 50,
  }) {
    return _fetchMessages(
      channelId,
      queryParameters: {'limit': limit.clamp(1, 100), 'around': messageId},
    );
  }

  @override
  Future<DiscordMessageSearchResult> searchGuildMessages(
    String guildId,
    String query, {
    String? channelId,
    int offset = 0,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw const InvalidMessageSearchException('검색어를 입력해 주세요.');
    }
    if (normalized.length > 1024) {
      throw const InvalidMessageSearchException('검색어는 1024자 이하여야 합니다.');
    }
    for (var attempt = 0; attempt < 3; attempt += 1) {
      final body = await _api.get(
        '/guilds/$guildId/messages/search',
        queryParameters: {
          'content': normalized,
          if (channelId != null) 'channel_id': [channelId],
          'limit': 25,
          'offset': offset.clamp(0, 9975),
          'sort_by': 'relevance',
          'sort_order': 'desc',
        },
      );
      if (_isSearchIndexPending(body)) {
        if (attempt == 2) {
          throw const InvalidMessageSearchException(
            'Discord 검색 색인 생성이 아직 끝나지 않았습니다. 잠시 후 다시 시도해 주세요.',
          );
        }
        await _delay(_searchRetryDelay(body));
        continue;
      }
      return _readSearchResult(body, guildId, normalized);
    }
    throw const InvalidMessageSearchException('Discord 메시지 검색에 실패했습니다.');
  }

  Future<List<DiscordMessage>> _fetchMessages(
    String channelId, {
    required Map<String, Object?> queryParameters,
  }) async {
    final body = await _api.get(
      '/channels/$channelId/messages',
      queryParameters: queryParameters,
    );
    if (body is! List) {
      throw const FormatException('메시지 목록 형식이 올바르지 않습니다.');
    }
    final messages = [
      for (final item in body) DiscordMessage.fromJson(_readMessage(item)),
    ];
    messages.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return List.unmodifiable(messages);
  }

  @override
  Future<DiscordMessage> sendMessage(String channelId, String content) async {
    return _sendMessage(channelId, content);
  }

  @override
  Future<DiscordMessage> sendStickers(
    String channelId,
    List<String> stickerIds, {
    String content = '',
  }) async {
    final normalizedStickerIds = [
      for (final stickerId in stickerIds)
        if (stickerId.trim().isNotEmpty) stickerId.trim(),
    ];
    if (normalizedStickerIds.isEmpty || normalizedStickerIds.length > 3) {
      throw const InvalidMessageException('스티커는 1~3개까지 전송할 수 있습니다.');
    }
    final normalizedContent = content.trim();
    if (normalizedContent.length > 2000) {
      throw const InvalidMessageException('메시지는 2000자 이하여야 합니다.');
    }
    final body = await _api.post(
      '/channels/$channelId/messages',
      data: {
        if (normalizedContent.isNotEmpty) 'content': normalizedContent,
        'sticker_ids': List.unmodifiable(normalizedStickerIds),
      },
    );
    return DiscordMessage.fromJson(_readMessage(body));
  }

  @override
  Future<DiscordMessage> sendReply(
    String channelId,
    String content,
    String messageId,
  ) {
    return _sendMessage(
      channelId,
      content,
      messageReference: {
        'message_id': messageId,
        'channel_id': channelId,
        'fail_if_not_exists': false,
      },
    );
  }

  @override
  Future<void> addReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    final encodedEmoji = Uri.encodeComponent(emoji);
    await _api.put(
      '/channels/$channelId/messages/$messageId/reactions/$encodedEmoji/@me',
    );
  }

  @override
  Future<void> removeReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    final encodedEmoji = Uri.encodeComponent(emoji);
    await _api.delete(
      '/channels/$channelId/messages/$messageId/reactions/$encodedEmoji/@me',
    );
  }

  @override
  Future<DiscordMessage> editMessage(
    String channelId,
    String messageId,
    String content,
  ) async {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw const InvalidMessageException('수정할 메시지를 입력해 주세요.');
    }
    if (normalized.length > 2000) {
      throw const InvalidMessageException('메시지는 2000자 이하여야 합니다.');
    }
    final body = await _api.patch(
      '/channels/$channelId/messages/$messageId',
      data: {'content': normalized},
    );
    return DiscordMessage.fromJson(_readMessage(body));
  }

  @override
  Future<void> deleteMessage(String channelId, String messageId) async {
    await _api.delete('/channels/$channelId/messages/$messageId');
  }

  @override
  Future<void> setPinned(
    String channelId,
    String messageId,
    bool pinned,
  ) async {
    final path = '/channels/$channelId/messages/pins/$messageId';
    if (pinned) {
      await _api.put(path);
    } else {
      await _api.delete(path);
    }
  }

  @override
  Future<void> triggerTyping(String channelId) async {
    await _api.post('/channels/$channelId/typing');
  }

  @override
  Future<DiscordMessage> sendAttachments(
    String channelId,
    String content,
    List<DiscordUploadFile> files, {
    String? replyToMessageId,
  }) async {
    if (files.isEmpty) {
      throw const InvalidMessageException('첨부할 파일을 선택해 주세요.');
    }
    if (files.length > 10) {
      throw const InvalidMessageException('첨부 파일은 최대 10개까지 전송할 수 있습니다.');
    }
    final totalBytes = files.fold<int>(
      0,
      (total, file) => total + file.bytes.length,
    );
    if (totalBytes > 25 * 1024 * 1024) {
      throw const InvalidMessageException('전체 첨부 크기는 25 MiB 이하여야 합니다.');
    }
    final normalized = content.trim();
    if (normalized.length > 2000) {
      throw const InvalidMessageException('메시지는 2000자 이하여야 합니다.');
    }
    final body = await _api.postMultipart(
      '/channels/$channelId/messages',
      payload: {
        if (normalized.isNotEmpty) 'content': normalized,
        'attachments': [
          for (var index = 0; index < files.length; index += 1)
            {
              'id': index,
              'filename': files[index].filename,
              'description': ?files[index].description,
            },
        ],
        if (replyToMessageId != null)
          'message_reference': {
            'message_id': replyToMessageId,
            'channel_id': channelId,
            'fail_if_not_exists': false,
          },
      },
      files: files,
    );
    return DiscordMessage.fromJson(_readMessage(body));
  }

  Future<DiscordMessage> _sendMessage(
    String channelId,
    String content, {
    Map<String, Object?>? messageReference,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw const InvalidMessageException('메시지를 입력해 주세요.');
    }
    if (normalized.length > 2000) {
      throw const InvalidMessageException('메시지는 2000자 이하여야 합니다.');
    }
    final body = await _api.post(
      '/channels/$channelId/messages',
      data: {'content': normalized, 'message_reference': ?messageReference},
    );
    return DiscordMessage.fromJson(_readMessage(body));
  }
}

bool _isSearchIndexPending(Object? value) {
  return value is Map && value['code'] == 110000;
}

Duration _searchRetryDelay(Object? value) {
  if (value is Map) {
    final retryAfter = value['retry_after'];
    if (retryAfter is num) {
      return Duration(milliseconds: (retryAfter * 1000).ceil());
    }
  }
  return const Duration(seconds: 1);
}

DiscordMessageSearchResult _readSearchResult(
  Object? value,
  String guildId,
  String query,
) {
  final body = _readMap(value, '검색 결과');
  final messages = <String, DiscordMessage>{};
  for (final group in _readList(body['messages'])) {
    for (final item in _readList(group)) {
      final message = DiscordMessage.fromJson(_readMessage(item));
      messages[message.id] = message;
    }
  }
  final memberIds = {
    for (final item in _readList(body['members']))
      if (_readMap(item, 'thread member')['id'] case final String id) id,
  };
  final threads = [
    for (final item in _readList(body['threads']))
      DiscordChannel.fromJson(
        _readMap(item, 'thread'),
        fallbackGuildId: guildId,
      ).copyWith(joined: memberIds.contains(_readMap(item, 'thread')['id'])),
  ];
  return DiscordMessageSearchResult(
    query: query,
    totalResults: switch (body['total_results']) {
      final num count => count.toInt(),
      _ => messages.length,
    },
    messages: List.unmodifiable(messages.values),
    threads: List.unmodifiable(threads),
  );
}

Map<String, Object?> _readMessage(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('메시지 형식이 올바르지 않습니다.');
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
