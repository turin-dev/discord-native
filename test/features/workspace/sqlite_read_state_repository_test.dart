import 'dart:io';

import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  sqfliteFfiInit();

  group('SqliteReadStateRepository', () {
    late Directory directory;
    late String databasePath;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'discord-native-read-state-',
      );
      databasePath = path.join(directory.path, 'discord_native.db');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('채널별 last-read와 unread count를 재시작 후 복원한다', () async {
      final repository = SqliteReadStateRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: () async => databasePath,
      );
      final updatedAt = DateTime.utc(2026, 7, 16, 10);

      await repository.save(
        DiscordReadState(
          channelId: 'channel-1',
          lastReadMessageId: 'message-1',
          unreadCount: 3,
          updatedAt: updatedAt,
        ),
      );
      await repository.dispose();

      final reopened = SqliteReadStateRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: () async => databasePath,
      );
      final states = await reopened.loadAll();

      expect(states['channel-1']?.lastReadMessageId, 'message-1');
      expect(states['channel-1']?.unreadCount, 3);
      expect(states['channel-1']?.updatedAt, updatedAt);
      await reopened.dispose();
    });

    test('같은 채널 저장은 immutable upsert하고 clear가 전체 삭제한다', () async {
      final repository = SqliteReadStateRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: () async => databasePath,
      );
      final first = DiscordReadState(
        channelId: 'channel-1',
        lastReadMessageId: 'message-1',
        unreadCount: 2,
        updatedAt: DateTime.utc(2026, 7, 16, 10),
      );
      final next = DiscordReadState(
        channelId: 'channel-1',
        lastReadMessageId: 'message-2',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 7, 16, 11),
      );

      await repository.save(first);
      await repository.save(next);
      final loaded = await repository.loadAll();

      expect(first.lastReadMessageId, 'message-1');
      expect(loaded.values, [next]);

      await repository.clear();
      expect(await repository.loadAll(), isEmpty);
      await repository.dispose();
    });
  });
}
