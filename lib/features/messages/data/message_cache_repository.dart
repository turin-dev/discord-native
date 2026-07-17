import 'dart:convert';

import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef MessageCacheDatabasePathProvider = Future<String> Function();

abstract interface class MessageCacheRepository {
  Future<List<DiscordMessage>> load({
    required String accountId,
    required String channelId,
    int limit = 50,
  });

  Future<void> replace({
    required String accountId,
    required String channelId,
    required List<DiscordMessage> messages,
  });

  Future<void> save({
    required String accountId,
    required DiscordMessage message,
  });

  Future<void> delete({
    required String accountId,
    required String channelId,
    required String messageId,
  });

  Future<void> clearAccount(String accountId);

  Future<void> dispose();
}

final class SqliteMessageCacheRepository implements MessageCacheRepository {
  SqliteMessageCacheRepository({
    required DatabaseFactory databaseFactory,
    required MessageCacheDatabasePathProvider databasePath,
    this.maxMessagesPerChannel = 100,
  }) : _databaseFactory = databaseFactory,
       _databasePath = databasePath {
    if (maxMessagesPerChannel < 1) {
      throw ArgumentError.value(
        maxMessagesPerChannel,
        'maxMessagesPerChannel',
        '1 이상이어야 합니다.',
      );
    }
  }

  final DatabaseFactory _databaseFactory;
  final MessageCacheDatabasePathProvider _databasePath;
  final int maxMessagesPerChannel;
  Future<Database>? _databaseFuture;
  bool _disposed = false;

  @override
  Future<List<DiscordMessage>> load({
    required String accountId,
    required String channelId,
    int limit = 50,
  }) async {
    _validateScope(accountId, channelId);
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', '1 이상이어야 합니다.');
    }
    final database = await _database();
    final rows = await database.query(
      _table,
      columns: const ['message_id', 'payload'],
      where: 'account_id = ? AND channel_id = ?',
      whereArgs: [accountId, channelId],
      orderBy: 'message_timestamp DESC',
      limit: limit,
    );
    final messages = <DiscordMessage>[];
    for (final row in rows) {
      try {
        messages.add(_decodeMessage(row['payload']! as String));
      } on FormatException {
        await database.delete(
          _table,
          where: 'account_id = ? AND channel_id = ? AND message_id = ?',
          whereArgs: [accountId, channelId, row['message_id']],
        );
      }
    }
    messages.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return List.unmodifiable(messages);
  }

  @override
  Future<void> replace({
    required String accountId,
    required String channelId,
    required List<DiscordMessage> messages,
  }) async {
    _validateScope(accountId, channelId);
    final sorted = List.of(messages)
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final retained = sorted.length > maxMessagesPerChannel
        ? sorted.sublist(sorted.length - maxMessagesPerChannel)
        : sorted;
    final database = await _database();
    await database.transaction((transaction) async {
      await transaction.delete(
        _table,
        where: 'account_id = ? AND channel_id = ?',
        whereArgs: [accountId, channelId],
      );
      final batch = transaction.batch();
      for (final message in retained) {
        batch.insert(_table, _row(accountId, message));
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> save({
    required String accountId,
    required DiscordMessage message,
  }) async {
    _validateScope(accountId, message.channelId);
    final database = await _database();
    await database.transaction((transaction) async {
      await transaction.insert(
        _table,
        _row(accountId, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.rawDelete(
        '''
DELETE FROM $_table
WHERE account_id = ? AND channel_id = ? AND message_id NOT IN (
  SELECT message_id FROM $_table
  WHERE account_id = ? AND channel_id = ?
  ORDER BY message_timestamp DESC
  LIMIT ?
)
''',
        [
          accountId,
          message.channelId,
          accountId,
          message.channelId,
          maxMessagesPerChannel,
        ],
      );
    });
  }

  @override
  Future<void> delete({
    required String accountId,
    required String channelId,
    required String messageId,
  }) async {
    _validateScope(accountId, channelId);
    if (messageId.isEmpty) {
      throw const FormatException('메시지 ID가 비어 있습니다.');
    }
    final database = await _database();
    await database.delete(
      _table,
      where: 'account_id = ? AND channel_id = ? AND message_id = ?',
      whereArgs: [accountId, channelId, messageId],
    );
  }

  @override
  Future<void> clearAccount(String accountId) async {
    if (accountId.isEmpty) {
      throw const FormatException('계정 ID가 비어 있습니다.');
    }
    final database = await _database();
    await database.delete(
      _table,
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final databaseFuture = _databaseFuture;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
    }
  }

  Future<Database> _database() {
    if (_disposed) {
      throw StateError('이미 종료된 message cache repository입니다.');
    }
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    return _databaseFactory.openDatabase(
      await _databasePath(),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
CREATE TABLE $_table (
  account_id TEXT NOT NULL,
  channel_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  message_timestamp INTEGER NOT NULL,
  payload TEXT NOT NULL,
  PRIMARY KEY (account_id, channel_id, message_id)
)
'''),
      ),
    );
  }
}

const _table = 'message_cache';

Map<String, Object?> _row(String accountId, DiscordMessage message) {
  return {
    'account_id': accountId,
    'channel_id': message.channelId,
    'message_id': message.id,
    'message_timestamp': message.timestamp.toUtc().millisecondsSinceEpoch,
    'payload': jsonEncode(_messageJson(message)),
  };
}

DiscordMessage _decodeMessage(String payload) {
  final decoded = jsonDecode(payload);
  if (decoded is! Map) {
    throw const FormatException('캐시 메시지 형식이 올바르지 않습니다.');
  }
  return DiscordMessage.fromJson(
    decoded.map((key, value) => MapEntry(key.toString(), value)),
  );
}

Map<String, Object?> _messageJson(DiscordMessage message) {
  return {
    'id': message.id,
    'channel_id': message.channelId,
    'content': message.content,
    'author': {
      'id': message.authorId,
      'username': message.authorName,
      'global_name': message.authorName,
    },
    'timestamp': message.timestamp.toUtc().toIso8601String(),
    'edited_timestamp': message.editedTimestamp?.toUtc().toIso8601String(),
    'message_reference': ?_referenceJson(message.reference),
    'referenced_message': message.referencedMessage == null
        ? null
        : _messageJson(message.referencedMessage!),
    'attachments': [
      for (final attachment in message.attachments)
        {
          'id': attachment.id,
          'filename': attachment.filename,
          'url': attachment.url,
          'proxy_url': attachment.proxyUrl,
          'size': attachment.size,
          'content_type': attachment.contentType,
          'width': attachment.width,
          'height': attachment.height,
        },
    ],
    'reactions': [
      for (final reaction in message.reactions)
        {
          'emoji': {'id': reaction.emojiId, 'name': reaction.emojiName},
          'count': reaction.count,
          'me': reaction.me,
        },
    ],
    'mentions': [
      for (final mention in message.mentions)
        {
          'id': mention.id,
          'username': mention.username,
          'global_name': mention.displayName,
        },
    ],
    'mention_roles': message.mentionRoleIds,
    'sticker_items': [
      for (final sticker in message.stickers)
        {
          'id': sticker.id,
          'name': sticker.name,
          'format_type': sticker.formatType,
        },
    ],
    'pinned': message.pinned,
  };
}

Map<String, Object?>? _referenceJson(DiscordMessageReference? reference) {
  if (reference == null) {
    return null;
  }
  return {
    'message_id': reference.messageId,
    'channel_id': reference.channelId,
    'guild_id': reference.guildId,
  };
}

void _validateScope(String accountId, String channelId) {
  if (accountId.isEmpty || channelId.isEmpty) {
    throw const FormatException('캐시 계정과 채널 ID가 필요합니다.');
  }
}
