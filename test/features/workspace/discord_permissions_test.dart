import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_permissions.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordPermissionCalculator', () {
    test('role overwrite는 deny를 합친 뒤 allow를 적용한다', () {
      final guild = DiscordGuild(
        id: 'guild-1',
        name: '개발 서버',
        roles: [
          DiscordRole(
            id: 'guild-1',
            name: '@everyone',
            position: 0,
            permissions: DiscordPermissions.viewChannel,
          ),
          DiscordRole(
            id: 'role-deny',
            name: '비공개',
            position: 1,
            permissions: DiscordPermissions.sendMessages,
          ),
          DiscordRole(
            id: 'role-allow',
            name: '허용',
            position: 2,
            permissions: DiscordPermissions.manageMessages,
          ),
        ],
      );
      final channel = DiscordChannel(
        id: 'channel-1',
        guildId: guild.id,
        name: 'general',
        type: 0,
        position: 0,
        permissionOverwrites: [
          DiscordPermissionOverwrite(
            id: guild.id,
            type: DiscordPermissionOverwriteType.role,
            allow: BigInt.zero,
            deny: DiscordPermissions.sendMessages,
          ),
          DiscordPermissionOverwrite(
            id: 'role-deny',
            type: DiscordPermissionOverwriteType.role,
            allow: BigInt.zero,
            deny: DiscordPermissions.viewChannel,
          ),
          DiscordPermissionOverwrite(
            id: 'role-allow',
            type: DiscordPermissionOverwriteType.role,
            allow: DiscordPermissions.viewChannel,
            deny: BigInt.zero,
          ),
          DiscordPermissionOverwrite(
            id: 'user-1',
            type: DiscordPermissionOverwriteType.member,
            allow: DiscordPermissions.sendMessages,
            deny: BigInt.zero,
          ),
        ],
      );
      const member = DiscordGuildMember(
        guildId: 'guild-1',
        user: DiscordUser(id: 'user-1', username: 'alice'),
        roleIds: ['role-deny', 'role-allow'],
      );

      final permissions = DiscordPermissionCalculator.compute(
        guild: guild,
        channel: channel,
        member: member,
      );

      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.viewChannel),
        isTrue,
      );
      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.sendMessages),
        isTrue,
      );
      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.manageMessages),
        isTrue,
      );
    });

    test('owner와 administrator는 channel deny를 우회한다', () {
      final guild = DiscordGuild(
        id: 'guild-1',
        name: '개발 서버',
        ownerId: 'owner-1',
        roles: [
          DiscordRole(
            id: 'guild-1',
            name: '@everyone',
            position: 0,
            permissions: BigInt.zero,
          ),
          DiscordRole(
            id: 'role-admin',
            name: '관리자',
            position: 1,
            permissions: DiscordPermissions.administrator,
          ),
        ],
      );
      final channel = DiscordChannel(
        id: 'channel-1',
        guildId: guild.id,
        name: '비공개',
        type: 0,
        position: 0,
        permissionOverwrites: [
          DiscordPermissionOverwrite(
            id: guild.id,
            type: DiscordPermissionOverwriteType.role,
            allow: BigInt.zero,
            deny: DiscordPermissions.all,
          ),
        ],
      );
      const owner = DiscordGuildMember(
        guildId: 'guild-1',
        user: DiscordUser(id: 'owner-1', username: 'owner'),
        roleIds: [],
      );
      const administrator = DiscordGuildMember(
        guildId: 'guild-1',
        user: DiscordUser(id: 'admin-1', username: 'admin'),
        roleIds: ['role-admin'],
      );

      for (final member in [owner, administrator]) {
        final permissions = DiscordPermissionCalculator.compute(
          guild: guild,
          channel: channel,
          member: member,
        );
        expect(
          DiscordPermissions.has(permissions, DiscordPermissions.viewChannel),
          isTrue,
        );
        expect(
          DiscordPermissions.has(permissions, DiscordPermissions.sendMessages),
          isTrue,
        );
      }
    });

    test('thread는 parent overwrite와 SEND_MESSAGES_IN_THREADS를 사용한다', () {
      final guild = DiscordGuild(
        id: 'guild-1',
        name: '개발 서버',
        roles: [
          DiscordRole(
            id: 'guild-1',
            name: '@everyone',
            position: 0,
            permissions:
                DiscordPermissions.viewChannel |
                DiscordPermissions.sendMessagesInThreads,
          ),
        ],
      );
      final parent = DiscordChannel(
        id: 'channel-1',
        guildId: guild.id,
        name: 'general',
        type: 0,
        position: 0,
        permissionOverwrites: [
          DiscordPermissionOverwrite(
            id: guild.id,
            type: DiscordPermissionOverwriteType.role,
            allow: BigInt.zero,
            deny: DiscordPermissions.sendMessages,
          ),
        ],
      );
      const thread = DiscordChannel(
        id: 'thread-1',
        guildId: 'guild-1',
        name: '설계 토론',
        type: 11,
        position: 0,
        parentId: 'channel-1',
      );
      const member = DiscordGuildMember(
        guildId: 'guild-1',
        user: DiscordUser(id: 'user-1', username: 'alice'),
        roleIds: [],
      );

      final permissions = DiscordPermissionCalculator.compute(
        guild: guild,
        channel: thread,
        member: member,
        parentChannel: parent,
      );

      expect(DiscordPermissions.canSend(permissions, channel: thread), isTrue);
      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.sendMessages),
        isFalse,
      );
    });

    test('timeout 중인 member는 보기와 기록 읽기 권한만 유지한다', () {
      final guild = DiscordGuild(
        id: 'guild-1',
        name: '개발 서버',
        roles: [
          DiscordRole(
            id: 'guild-1',
            name: '@everyone',
            position: 0,
            permissions:
                DiscordPermissions.viewChannel |
                DiscordPermissions.readMessageHistory |
                DiscordPermissions.sendMessages |
                DiscordPermissions.manageMessages,
          ),
        ],
      );
      const channel = DiscordChannel(
        id: 'channel-1',
        guildId: 'guild-1',
        name: 'general',
        type: 0,
        position: 0,
      );
      final member = DiscordGuildMember(
        guildId: 'guild-1',
        user: const DiscordUser(id: 'user-1', username: 'alice'),
        roleIds: const [],
        communicationDisabledUntil: DateTime.utc(2026, 7, 18),
      );

      final permissions = DiscordPermissionCalculator.compute(
        guild: guild,
        channel: channel,
        member: member,
        now: DateTime.utc(2026, 7, 17),
      );

      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.viewChannel),
        isTrue,
      );
      expect(
        DiscordPermissions.has(
          permissions,
          DiscordPermissions.readMessageHistory,
        ),
        isTrue,
      );
      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.sendMessages),
        isFalse,
      );
      expect(
        DiscordPermissions.has(permissions, DiscordPermissions.manageMessages),
        isFalse,
      );
    });
  });
}
