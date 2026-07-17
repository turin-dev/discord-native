import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef DatabasePathProvider = Future<String> Function();

final class DiscordReadState {
  const DiscordReadState({
    required this.channelId,
    required this.lastReadMessageId,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory DiscordReadState.initial(String channelId) {
    return DiscordReadState(
      channelId: channelId,
      lastReadMessageId: null,
      unreadCount: 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String channelId;
  final String? lastReadMessageId;
  final int unreadCount;
  final DateTime updatedAt;

  DiscordReadState markRead(String? messageId, DateTime now) {
    return DiscordReadState(
      channelId: channelId,
      lastReadMessageId: messageId ?? lastReadMessageId,
      unreadCount: 0,
      updatedAt: now.toUtc(),
    );
  }

  DiscordReadState incrementUnread(DateTime now) {
    return DiscordReadState(
      channelId: channelId,
      lastReadMessageId: lastReadMessageId,
      unreadCount: unreadCount + 1,
      updatedAt: now.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiscordReadState &&
        other.channelId == channelId &&
        other.lastReadMessageId == lastReadMessageId &&
        other.unreadCount == unreadCount &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(channelId, lastReadMessageId, unreadCount, updatedAt);
  }
}

abstract interface class ReadStateRepository {
  Future<Map<String, DiscordReadState>> loadAll();

  Future<void> save(DiscordReadState state);

  Future<void> clear();

  Future<void> dispose();
}

final class SqliteReadStateRepository implements ReadStateRepository {
  SqliteReadStateRepository({
    required DatabaseFactory databaseFactory,
    required DatabasePathProvider databasePath,
  }) : _databaseFactory = databaseFactory,
       _databasePath = databasePath;

  final DatabaseFactory _databaseFactory;
  final DatabasePathProvider _databasePath;
  Future<Database>? _databaseFuture;
  bool _disposed = false;

  @override
  Future<Map<String, DiscordReadState>> loadAll() async {
    final database = await _database();
    final rows = await database.query(_table, orderBy: 'channel_id ASC');
    return Map.unmodifiable({
      for (final row in rows) row['channel_id']! as String: _readState(row),
    });
  }

  @override
  Future<void> save(DiscordReadState state) async {
    final database = await _database();
    await database.insert(_table, {
      'channel_id': state.channelId,
      'last_read_message_id': state.lastReadMessageId,
      'unread_count': state.unreadCount,
      'updated_at': state.updatedAt.toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    final database = await _database();
    await database.delete(_table);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final future = _databaseFuture;
    if (future != null) {
      await (await future).close();
    }
  }

  Future<Database> _database() {
    if (_disposed) {
      throw StateError('이미 종료된 read state repository입니다.');
    }
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    return _databaseFactory.openDatabase(
      await _databasePath(),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) {
          return database.execute('''
CREATE TABLE $_table (
  channel_id TEXT PRIMARY KEY,
  last_read_message_id TEXT,
  unread_count INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
        },
      ),
    );
  }
}

const String _table = 'channel_read_states';

DiscordReadState _readState(Map<String, Object?> row) {
  return DiscordReadState(
    channelId: row['channel_id']! as String,
    lastReadMessageId: row['last_read_message_id'] as String?,
    unreadCount: row['unread_count']! as int,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );
}
