import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordPeopleState', () {
    test('READY의 친구·요청·차단과 presence를 저장한다', () {
      final state = const DiscordPeopleState().payloadReceived({
        'op': 0,
        't': 'READY',
        'd': {
          'relationships': [
            {
              'id': 'user-2',
              'type': 1,
              'nickname': '밥',
              'user': {'id': 'user-2', 'username': 'bob'},
            },
            {
              'id': 'user-3',
              'type': 3,
              'user': {'id': 'user-3', 'username': 'carol'},
            },
            {
              'id': 'user-4',
              'type': 2,
              'user': {'id': 'user-4', 'username': 'dave'},
            },
          ],
          'presences': [
            {
              'user': {'id': 'user-2'},
              'status': 'online',
              'activities': [
                {'name': 'Flutter'},
              ],
            },
          ],
          'private_channels': [
            {
              'id': 'dm-1',
              'type': 1,
              'recipients': [
                {'id': 'user-2', 'username': 'bob'},
              ],
            },
          ],
        },
      });

      expect(state.friends.single.displayName, '밥');
      expect(state.incomingRequests.single.user.username, 'carol');
      expect(state.blocked.single.user.username, 'dave');
      expect(state.friends.single.status, DiscordPresenceStatus.online);
      expect(state.friends.single.activityName, 'Flutter');
    });

    test('READY users의 사용자를 recipient와 relationship ID에 결합한다', () {
      final state = const DiscordPeopleState().payloadReceived({
        'op': 0,
        't': 'READY',
        'd': {
          'users': [
            {'id': 'user-2', 'username': 'bob', 'global_name': 'Bob'},
          ],
          'relationships': [
            {'id': 'user-2', 'type': 1},
          ],
          'private_channels': [
            {
              'id': 'dm-1',
              'type': 1,
              'recipient_ids': ['user-2'],
            },
          ],
          'presences': [],
        },
      });

      expect(state.friends.single.user.username, 'bob');
      expect(state.friends.single.user.displayName, 'Bob');
    });

    test('guild member와 PRESENCE_UPDATE를 불변 갱신한다', () {
      final initial = const DiscordPeopleState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'members': [
            {
              'nick': '밥',
              'roles': ['role-1'],
              'user': {'id': 'user-2', 'username': 'bob'},
            },
          ],
          'presences': [
            {
              'user': {'id': 'user-2'},
              'guild_id': 'guild-1',
              'status': 'idle',
              'activities': [],
            },
          ],
        },
      });

      final updated = initial.payloadReceived({
        'op': 0,
        't': 'PRESENCE_UPDATE',
        'd': {
          'user': {'id': 'user-2', 'global_name': 'Bob'},
          'guild_id': 'guild-1',
          'status': 'dnd',
          'activities': [
            {'name': '회의 중'},
          ],
        },
      });

      final member = updated.membersForGuild('guild-1').single;
      expect(member.displayName, '밥');
      expect(member.status, DiscordPresenceStatus.dnd);
      expect(member.activityName, '회의 중');
      expect(
        initial.membersForGuild('guild-1').single.status,
        isNot(member.status),
      );
    });

    test('guild와 user ID로 timeout 중인 member를 찾는다', () {
      final state = const DiscordPeopleState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'members': [
            {
              'roles': ['role-1'],
              'communication_disabled_until': '2026-07-18T10:00:00.000Z',
              'user': {'id': 'user-1', 'username': 'alice'},
            },
          ],
          'presences': [],
        },
      });

      final member = state.memberForGuild('guild-1', 'user-1');

      expect(member?.user.username, 'alice');
      expect(member?.communicationDisabledUntil, DateTime.utc(2026, 7, 18, 10));
      expect(state.memberForGuild('guild-1', 'missing'), isNull);
    });
  });
}
