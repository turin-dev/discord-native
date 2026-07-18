import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordWorkspaceState', () {
    test('READY에서 현재 사용자와 부분 guild 목록을 읽는다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'native-user'},
          'guilds': [
            {'id': 'guild-1', 'name': '첫 서버'},
          ],
        },
      });

      expect(state.currentUser?.username, 'native-user');
      expect(state.guilds.single.name, '첫 서버');
    });

    test('READY의 1:1·group DM을 synthetic guild 채널로 구성한다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'native-user'},
          'guilds': [],
          'relationships': [
            {'id': 'user-2', 'type': 1},
          ],
          'private_channels': [
            {
              'id': 'dm-1',
              'type': 1,
              'last_message_id': 'message-2',
              'recipients': [
                {'id': 'user-2', 'username': 'bob', 'global_name': 'Bob'},
              ],
            },
            {
              'id': 'group-1',
              'type': 3,
              'name': '프로젝트 방',
              'last_message_id': 'message-1',
              'recipients': [
                {'id': 'user-2', 'username': 'bob'},
                {'id': 'user-3', 'username': 'carol'},
              ],
            },
          ],
        },
      });

      expect(state.guilds.first.id, discordDirectMessagesGuildId);
      expect(
        state.channelsForGuild(discordDirectMessagesGuildId),
        hasLength(2),
      );
      expect(state.channels.first.name, 'Bob');
      expect(state.channels.first.isPrivate, isTrue);
      expect(state.channels.first.isTextChannel, isTrue);
      expect(state.channels.last.name, '프로젝트 방');
    });

    test('READY users와 recipient_ids로 현대 DM 사용자를 해석한다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice'},
          'guilds': [],
          'users': [
            {'id': 'user-2', 'username': 'bob', 'global_name': 'Bob'},
            {'id': 'user-3', 'username': 'carol'},
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
            {
              'id': 'group-1',
              'type': 3,
              'recipient_ids': ['user-2', 'user-3'],
            },
          ],
        },
      });

      final directMessage = state.channelById('dm-1')!;
      final groupMessage = state.channelById('group-1')!;
      expect(directMessage.name, 'Bob');
      expect(directMessage.recipients.single.username, 'bob');
      expect(groupMessage.name, 'Bob, carol');
      expect(groupMessage.recipients, hasLength(2));
    });

    test('GUILD_CREATE 채널을 position 순서로 저장한다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-2',
              'guild_id': 'guild-1',
              'name': 'random',
              'type': 0,
              'position': 2,
            },
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 1,
            },
          ],
        },
      });

      expect(state.channelsForGuild('guild-1').map((channel) => channel.name), [
        'general',
        'random',
      ]);
    });

    test('CHANNEL_UNREAD_UPDATE로 채널의 최신 메시지를 불변 갱신한다', () {
      final initial = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
              'last_message_id': '100',
            },
          ],
        },
      });

      final updated = initial.payloadReceived({
        'op': 0,
        't': 'CHANNEL_UNREAD_UPDATE',
        'd': {
          'guild_id': 'guild-1',
          'channel_unread_updates': [
            {'id': 'channel-1', 'last_message_id': '250'},
          ],
        },
      });

      expect(initial.channels.single.lastMessageId, '100');
      expect(updated.channels.single.lastMessageId, '250');
      expect(updated.channels.single, isNot(same(initial.channels.single)));
    });

    test('GUILD_CREATE에서 owner, role, permission overwrite를 읽는다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'owner_id': 'user-owner',
          'roles': [
            {
              'id': 'guild-1',
              'name': '@everyone',
              'permissions': '1024',
              'position': 0,
              'color': 0,
            },
            {
              'id': 'role-1',
              'name': '관리자',
              'permissions': '2251799813693440',
              'position': 1,
              'color': 16711680,
            },
          ],
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
              'permission_overwrites': [
                {'id': 'guild-1', 'type': 0, 'allow': '2048', 'deny': '1024'},
              ],
            },
          ],
        },
      });

      final guild = state.guilds.single;
      final role = guild.roles.last;
      final overwrite = state.channels.single.permissionOverwrites.single;

      expect(guild.ownerId, 'user-owner');
      expect(role.name, '관리자');
      expect(role.permissions, BigInt.parse('2251799813693440'));
      expect(overwrite.type, DiscordPermissionOverwriteType.role);
      expect(overwrite.allow, BigInt.from(2048));
      expect(overwrite.deny, BigInt.from(1024));
    });

    test('GUILD_ROLE events를 불변 반영한다', () {
      final initial = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'roles': [
            {
              'id': 'guild-1',
              'name': '@everyone',
              'permissions': '1024',
              'position': 0,
              'color': 0,
            },
          ],
          'channels': [],
        },
      });
      final created = initial.payloadReceived({
        'op': 0,
        't': 'GUILD_ROLE_CREATE',
        'd': {
          'guild_id': 'guild-1',
          'role': {
            'id': 'role-1',
            'name': '운영진',
            'permissions': '8192',
            'position': 1,
            'color': 255,
          },
        },
      });
      final updated = created.payloadReceived({
        'op': 0,
        't': 'GUILD_ROLE_UPDATE',
        'd': {
          'guild_id': 'guild-1',
          'role': {
            'id': 'role-1',
            'name': '관리자',
            'permissions': '8200',
            'position': 2,
            'color': 16711680,
          },
        },
      });
      final deleted = updated.payloadReceived({
        'op': 0,
        't': 'GUILD_ROLE_DELETE',
        'd': {'guild_id': 'guild-1', 'role_id': 'role-1'},
      });

      expect(initial.guilds.single.roles, hasLength(1));
      expect(created.guilds.single.roles.last.name, '운영진');
      expect(updated.guilds.single.roles.last.name, '관리자');
      expect(updated.guilds.single.roles.last.permissions, BigInt.from(8200));
      expect(deleted.guilds.single.roles, hasLength(1));
    });

    test('GUILD_CREATE와 guild expression dispatch를 불변 반영한다', () {
      final initial = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [],
          'emojis': [
            {
              'id': 'emoji-1',
              'name': 'party',
              'animated': true,
              'available': true,
            },
          ],
          'stickers': [
            {
              'id': 'sticker-1',
              'name': 'Wumpus',
              'description': '인사하는 Wumpus',
              'tags': 'wave',
              'type': 2,
              'format_type': 1,
              'available': true,
              'guild_id': 'guild-1',
            },
          ],
        },
      });
      final emojisUpdated = initial.payloadReceived({
        'op': 0,
        't': 'GUILD_EMOJIS_UPDATE',
        'd': {
          'guild_id': 'guild-1',
          'emojis': [
            {
              'id': 'emoji-2',
              'name': 'wave',
              'animated': false,
              'available': true,
            },
          ],
        },
      });
      final stickersUpdated = emojisUpdated.payloadReceived({
        'op': 0,
        't': 'GUILD_STICKERS_UPDATE',
        'd': {
          'guild_id': 'guild-1',
          'stickers': [
            {
              'id': 'sticker-2',
              'name': 'Wave',
              'description': null,
              'tags': 'hello',
              'type': 2,
              'format_type': 4,
              'available': true,
              'guild_id': 'guild-1',
            },
          ],
        },
      });

      expect(
        initial.guilds.single.emojis.single.messageSyntax,
        '<a:party:emoji-1>',
      );
      expect(initial.guilds.single.stickers.single.name, 'Wumpus');
      expect(
        emojisUpdated.guilds.single.emojis.single.messageSyntax,
        '<:wave:emoji-2>',
      );
      expect(emojisUpdated.guilds.single.stickers.single.id, 'sticker-1');
      expect(stickersUpdated.guilds.single.stickers.single.id, 'sticker-2');
      expect(stickersUpdated.guilds.single.emojis.single.id, 'emoji-2');
      expect(initial.guilds.single.emojis.single.id, 'emoji-1');
    });

    test('GUILD_CREATE와 scheduled event dispatch를 불변 반영한다', () {
      final initial = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [],
          'guild_scheduled_events': [
            {
              'id': 'event-1',
              'guild_id': 'guild-1',
              'channel_id': null,
              'name': '정기 모임',
              'scheduled_start_time': '2026-07-20T10:00:00.000Z',
              'scheduled_end_time': '2026-07-20T12:00:00.000Z',
              'privacy_level': 2,
              'status': 1,
              'entity_type': 3,
              'entity_metadata': {'location': '서울'},
            },
          ],
        },
      });
      final updated = initial.payloadReceived({
        'op': 0,
        't': 'GUILD_SCHEDULED_EVENT_UPDATE',
        'd': {
          'id': 'event-1',
          'guild_id': 'guild-1',
          'channel_id': null,
          'name': '진행 중 모임',
          'scheduled_start_time': '2026-07-20T10:00:00.000Z',
          'scheduled_end_time': '2026-07-20T12:00:00.000Z',
          'privacy_level': 2,
          'status': 2,
          'entity_type': 3,
          'entity_metadata': {'location': '서울'},
        },
      });
      final deleted = updated.payloadReceived({
        'op': 0,
        't': 'GUILD_SCHEDULED_EVENT_DELETE',
        'd': {'id': 'event-1'},
      });

      expect(initial.scheduledEvents.single.name, '정기 모임');
      expect(updated.scheduledEvents.single.name, '진행 중 모임');
      expect(initial.scheduledEvents.single.name, isNot('진행 중 모임'));
      expect(deleted.scheduledEvents, isEmpty);
    });

    test('category와 하위 channel을 트리 순서로 저장한다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-2',
              'guild_id': 'guild-1',
              'parent_id': 'category-1',
              'name': 'random',
              'type': 0,
              'position': 2,
            },
            {
              'id': 'category-1',
              'guild_id': 'guild-1',
              'name': '개발',
              'type': 4,
              'position': 0,
            },
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'parent_id': 'category-1',
              'name': 'general',
              'type': 0,
              'position': 1,
            },
          ],
        },
      });

      expect(state.channelsForGuild('guild-1').map((channel) => channel.id), [
        'category-1',
        'channel-1',
        'channel-2',
      ]);
      expect(state.channels.first.isCategory, isTrue);
    });

    test('존재하지 않는 category의 하위 channel을 숨기지 않는다', () {
      final state = DiscordWorkspaceState.fromCollections(
        guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
        channels: const [
          DiscordChannel(
            id: 'channel-1',
            guildId: 'guild-1',
            name: '고아 채널',
            type: 0,
            position: 1,
            parentId: 'missing-category',
          ),
        ],
      );

      expect(state.channelsForGuild('guild-1').single.id, 'channel-1');
    });

    test('CHANNEL_UPDATE와 CHANNEL_DELETE를 불변 갱신한다', () {
      final initial = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 1,
            },
          ],
        },
      });

      final updated = initial.payloadReceived({
        'op': 0,
        't': 'CHANNEL_UPDATE',
        'd': {
          'id': 'channel-1',
          'guild_id': 'guild-1',
          'name': 'announcements',
          'type': 0,
          'position': 1,
        },
      });
      final deleted = updated.payloadReceived({
        'op': 0,
        't': 'CHANNEL_DELETE',
        'd': {'id': 'channel-1'},
      });

      expect(initial.channels.single.name, 'general');
      expect(updated.channels.single.name, 'announcements');
      expect(deleted.channels, isEmpty);
    });

    test('GUILD_CREATE의 active thread와 thread metadata를 저장한다', () {
      final state = const DiscordWorkspaceState().payloadReceived({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
          'threads': [
            {
              'id': 'thread-1',
              'guild_id': 'guild-1',
              'parent_id': 'channel-1',
              'name': '설계 토론',
              'type': 11,
              'position': 0,
              'member': {'id': 'thread-1', 'user_id': 'user-1'},
              'thread_metadata': {
                'archived': false,
                'locked': false,
                'auto_archive_duration': 1440,
                'archive_timestamp': '2026-07-16T10:00:00.000Z',
              },
            },
          ],
        },
      });

      final thread = state.channels.singleWhere((item) => item.isThread);
      expect(thread.parentId, 'channel-1');
      expect(thread.isArchived, isFalse);
      expect(thread.joined, isTrue);
      expect(thread.threadMetadata?.autoArchiveDuration, 1440);
    });

    test('THREAD events와 THREAD_LIST_SYNC를 불변 반영한다', () {
      final initial = DiscordWorkspaceState.fromCollections(
        guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
        channels: const [
          DiscordChannel(
            id: 'channel-1',
            guildId: 'guild-1',
            name: 'general',
            type: 0,
            position: 0,
          ),
          DiscordChannel(
            id: 'thread-old',
            guildId: 'guild-1',
            name: '이전 스레드',
            type: 11,
            position: 0,
            parentId: 'channel-1',
          ),
        ],
      );

      final synced = initial.payloadReceived({
        'op': 0,
        't': 'THREAD_LIST_SYNC',
        'd': {
          'guild_id': 'guild-1',
          'channel_ids': ['channel-1'],
          'threads': [
            {
              'id': 'thread-new',
              'guild_id': 'guild-1',
              'parent_id': 'channel-1',
              'name': '새 스레드',
              'type': 11,
              'position': 0,
              'thread_metadata': {
                'archived': false,
                'locked': false,
                'auto_archive_duration': 60,
                'archive_timestamp': '2026-07-16T11:00:00.000Z',
              },
            },
          ],
        },
      });
      final updated = synced.payloadReceived({
        'op': 0,
        't': 'THREAD_UPDATE',
        'd': {
          'id': 'thread-new',
          'guild_id': 'guild-1',
          'parent_id': 'channel-1',
          'name': '갱신된 스레드',
          'type': 11,
          'position': 0,
          'thread_metadata': {
            'archived': true,
            'locked': false,
            'auto_archive_duration': 60,
            'archive_timestamp': '2026-07-16T11:30:00.000Z',
          },
        },
      });
      final deleted = updated.payloadReceived({
        'op': 0,
        't': 'THREAD_DELETE',
        'd': {'id': 'thread-new'},
      });

      expect(synced.channels.any((item) => item.id == 'thread-old'), isFalse);
      expect(synced.channels.any((item) => item.id == 'thread-new'), isTrue);
      expect(
        updated.channels.singleWhere((item) => item.id == 'thread-new').name,
        '갱신된 스레드',
      );
      expect(
        updated.channels
            .singleWhere((item) => item.id == 'thread-new')
            .isArchived,
        isTrue,
      );
      expect(deleted.channels.any((item) => item.id == 'thread-new'), isFalse);
    });
  });
}
