import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordTypingState', () {
    test('TYPING_START의 member 이름을 10초 만료 상태로 저장하고 자신은 제외한다', () {
      final now = DateTime.utc(2026, 7, 16, 10);
      final initial = const DiscordTypingState();

      final typing = initial.payloadReceived(
        {
          'op': 0,
          't': 'TYPING_START',
          'd': {
            'channel_id': 'channel-1',
            'user_id': 'user-2',
            'timestamp': 1784196000,
            'member': {
              'nick': '밥',
              'user': {'id': 'user-2', 'username': 'bob'},
            },
          },
        },
        now: now,
        currentUserId: 'user-1',
      );
      final ignoredSelf = typing.payloadReceived(
        {
          'op': 0,
          't': 'TYPING_START',
          'd': {
            'channel_id': 'channel-1',
            'user_id': 'user-1',
            'timestamp': 1784196000,
          },
        },
        now: now,
        currentUserId: 'user-1',
      );

      final user = typing.usersForChannel('channel-1').single;
      expect(user.displayName, '밥');
      expect(user.expiresAt, now.add(const Duration(seconds: 10)));
      expect(ignoredSelf.usersForChannel('channel-1'), hasLength(1));
      expect(initial.usersForChannel('channel-1'), isEmpty);
    });

    test('MESSAGE_CREATE와 일치하는 만료 시점에 typing 사용자를 제거한다', () {
      final now = DateTime.utc(2026, 7, 16, 10);
      final typing = const DiscordTypingState().payloadReceived(
        {
          'op': 0,
          't': 'TYPING_START',
          'd': {
            'channel_id': 'channel-1',
            'user_id': 'user-2',
            'timestamp': 1784196000,
          },
        },
        now: now,
        currentUserId: 'user-1',
      );
      final refreshed = typing.payloadReceived(
        {
          'op': 0,
          't': 'TYPING_START',
          'd': {
            'channel_id': 'channel-1',
            'user_id': 'user-2',
            'timestamp': 1784196001,
          },
        },
        now: now.add(const Duration(seconds: 5)),
        currentUserId: 'user-1',
      );

      final staleExpiry = refreshed.expire(
        'channel-1',
        'user-2',
        now.add(const Duration(seconds: 10)),
      );
      final messageCreated = refreshed.payloadReceived(
        {
          'op': 0,
          't': 'MESSAGE_CREATE',
          'd': {
            'id': 'message-1',
            'channel_id': 'channel-1',
            'author': {'id': 'user-2'},
          },
        },
        now: now.add(const Duration(seconds: 6)),
        currentUserId: 'user-1',
      );

      expect(staleExpiry.usersForChannel('channel-1'), hasLength(1));
      expect(messageCreated.usersForChannel('channel-1'), isEmpty);
    });
  });
}
