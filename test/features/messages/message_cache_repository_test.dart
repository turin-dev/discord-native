import 'package:discord_native/features/messages/data/message_cache_repository.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('SqliteMessageCacheRepository', () {
    late SqliteMessageCacheRepository repository;

    setUp(() {
      repository = SqliteMessageCacheRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: () async => inMemoryDatabasePath,
        maxMessagesPerChannel: 2,
      );
    });

    tearDown(() => repository.dispose());

    test('메시지와 표시 메타데이터를 SQLite에서 복원한다', () async {
      final message = _message('message-1', '첫 메시지');

      await repository.replace(
        accountId: 'user-1',
        channelId: 'channel-1',
        messages: [message],
      );
      final cached = await repository.load(
        accountId: 'user-1',
        channelId: 'channel-1',
      );

      expect(cached, hasLength(1));
      expect(cached.single.id, message.id);
      expect(cached.single.content, message.content);
      expect(cached.single.authorName, message.authorName);
      expect(cached.single.attachments.single.filename, 'image.png');
      expect(cached.single.reactions.single.emojiName, '👍');
      expect(cached.single.mentions.single.displayName, 'Bob');
    });

    test('같은 채널도 계정별로 완전히 격리한다', () async {
      await repository.replace(
        accountId: 'user-1',
        channelId: 'channel-1',
        messages: [_message('message-a', 'Alice cache')],
      );
      await repository.replace(
        accountId: 'user-2',
        channelId: 'channel-1',
        messages: [_message('message-b', 'Bob cache')],
      );

      final alice = await repository.load(
        accountId: 'user-1',
        channelId: 'channel-1',
      );
      final bob = await repository.load(
        accountId: 'user-2',
        channelId: 'channel-1',
      );

      expect(alice.single.content, 'Alice cache');
      expect(bob.single.content, 'Bob cache');
    });

    test('계정 전체 채널의 signed media proxy index를 복원한다', () async {
      const path = '/attachments/source-channel/attachment-1/X.gif';
      await repository.save(
        accountId: 'user-1',
        message: _mediaMessage(
          channelId: 'source-channel',
          url: 'https://cdn.discordapp.com$path?signature=current',
          proxyUrl:
              'https://media.discordapp.net$path?signature=current&width=400',
        ),
      );
      await repository.save(
        accountId: 'user-2',
        message: _mediaMessage(
          channelId: 'other-channel',
          url: 'https://cdn.discordapp.com$path?signature=other',
          proxyUrl: 'https://media.discordapp.net$path?signature=other',
        ),
      );

      final proxyUrls = await repository.loadMediaProxyUrls(
        accountId: 'user-1',
      );

      expect(proxyUrls, {
        path: 'https://media.discordapp.net$path?signature=current&width=400',
      });
    });

    test('채널별 최근 메시지 상한을 유지한다', () async {
      await repository.replace(
        accountId: 'user-1',
        channelId: 'channel-1',
        messages: [
          _message('message-1', '1', minute: 1),
          _message('message-2', '2', minute: 2),
          _message('message-3', '3', minute: 3),
        ],
      );

      final cached = await repository.load(
        accountId: 'user-1',
        channelId: 'channel-1',
      );

      expect(cached.map((message) => message.id), ['message-2', 'message-3']);
    });

    test('계정 캐시 삭제는 다른 계정 메시지를 유지한다', () async {
      await repository.replace(
        accountId: 'user-1',
        channelId: 'channel-1',
        messages: [_message('message-a', 'Alice cache')],
      );
      await repository.replace(
        accountId: 'user-2',
        channelId: 'channel-1',
        messages: [_message('message-b', 'Bob cache')],
      );

      await repository.clearAccount('user-1');

      expect(
        await repository.load(accountId: 'user-1', channelId: 'channel-1'),
        isEmpty,
      );
      expect(
        await repository.load(accountId: 'user-2', channelId: 'channel-1'),
        hasLength(1),
      );
    });

    test('incremental save는 upsert·pruning하고 delete로 제거한다', () async {
      await repository.save(
        accountId: 'user-1',
        message: _message('message-1', '1', minute: 1),
      );
      await repository.save(
        accountId: 'user-1',
        message: _message('message-2', '2', minute: 2),
      );
      await repository.save(
        accountId: 'user-1',
        message: _message('message-3', '3', minute: 3),
      );
      await repository.save(
        accountId: 'user-1',
        message: _message('message-2', '수정', minute: 4),
      );

      var cached = await repository.load(
        accountId: 'user-1',
        channelId: 'channel-1',
      );
      expect(cached.map((message) => message.id), ['message-3', 'message-2']);
      expect(cached.last.content, '수정');

      await repository.delete(
        accountId: 'user-1',
        channelId: 'channel-1',
        messageId: 'message-3',
      );
      cached = await repository.load(
        accountId: 'user-1',
        channelId: 'channel-1',
      );
      expect(cached.single.id, 'message-2');
    });

    test('잘못된 범위와 limit을 명시적으로 거부한다', () async {
      expect(
        () => repository.load(accountId: '', channelId: 'channel-1'),
        throwsFormatException,
      );
      expect(
        () => repository.load(
          accountId: 'user-1',
          channelId: 'channel-1',
          limit: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.delete(
          accountId: 'user-1',
          channelId: 'channel-1',
          messageId: '',
        ),
        throwsFormatException,
      );
    });
  });

  test('잘못된 채널 상한을 생성 시 거부한다', () {
    expect(
      () => SqliteMessageCacheRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: () async => inMemoryDatabasePath,
        maxMessagesPerChannel: 0,
      ),
      throwsArgumentError,
    );
  });
}

DiscordMessage _message(String id, String content, {int minute = 0}) {
  return DiscordMessage(
    id: id,
    channelId: 'channel-1',
    content: content,
    authorId: 'user-2',
    authorName: 'Alice',
    timestamp: DateTime.utc(2026, 7, 17, 12, minute),
    attachments: const [
      DiscordAttachment(
        id: 'attachment-1',
        filename: 'image.png',
        url: 'https://cdn.discordapp.com/image.png',
        proxyUrl: 'https://media.discordapp.net/image.png',
        size: 123,
        contentType: 'image/png',
        width: 64,
        height: 64,
      ),
    ],
    reactions: const [DiscordReaction(emojiName: '👍', count: 2, me: true)],
    mentions: const [
      DiscordMention(id: 'user-3', username: 'bob', displayName: 'Bob'),
    ],
    mentionRoleIds: const ['role-1'],
    pinned: true,
  );
}

DiscordMessage _mediaMessage({
  required String channelId,
  required String url,
  required String proxyUrl,
}) {
  return DiscordMessage(
    id: 'message-$channelId',
    channelId: channelId,
    content: '',
    authorId: 'user-2',
    authorName: 'Alice',
    timestamp: DateTime.utc(2026, 7, 18, 14),
    attachments: [
      DiscordAttachment(
        id: 'attachment-1',
        filename: 'X.gif',
        url: url,
        proxyUrl: proxyUrl,
        size: 1024,
        contentType: 'image/gif',
        width: 400,
        height: 225,
      ),
    ],
  );
}
