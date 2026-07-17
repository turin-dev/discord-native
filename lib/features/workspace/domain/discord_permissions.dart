import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

abstract final class DiscordPermissions {
  static final BigInt createInstantInvite = BigInt.one << 0;
  static final BigInt administrator = BigInt.one << 3;
  static final BigInt manageChannels = BigInt.one << 4;
  static final BigInt manageGuild = BigInt.one << 5;
  static final BigInt viewAuditLog = BigInt.one << 7;
  static final BigInt viewChannel = BigInt.one << 10;
  static final BigInt sendMessages = BigInt.one << 11;
  static final BigInt manageMessages = BigInt.one << 13;
  static final BigInt attachFiles = BigInt.one << 15;
  static final BigInt readMessageHistory = BigInt.one << 16;
  static final BigInt manageRoles = BigInt.one << 28;
  static final BigInt manageEvents = BigInt.one << 33;
  static final BigInt manageThreads = BigInt.one << 34;
  static final BigInt createPublicThreads = BigInt.one << 35;
  static final BigInt createPrivateThreads = BigInt.one << 36;
  static final BigInt sendMessagesInThreads = BigInt.one << 38;
  static final BigInt createEvents = BigInt.one << 44;
  static final BigInt pinMessages = BigInt.one << 51;
  static final BigInt all = (BigInt.one << 64) - BigInt.one;

  static bool has(BigInt permissions, BigInt permission) {
    return permissions & permission == permission;
  }

  static bool canSend(BigInt permissions, {required DiscordChannel channel}) {
    if (!has(permissions, viewChannel)) {
      return false;
    }
    final permission = channel.isThread ? sendMessagesInThreads : sendMessages;
    return has(permissions, permission);
  }
}

abstract final class DiscordPermissionCalculator {
  static BigInt computeBase({
    required DiscordGuild guild,
    required DiscordGuildMember member,
  }) {
    final permissions = _basePermissions(guild, member);
    return DiscordPermissions.has(permissions, DiscordPermissions.administrator)
        ? DiscordPermissions.all
        : permissions;
  }

  static BigInt compute({
    required DiscordGuild guild,
    required DiscordChannel channel,
    required DiscordGuildMember member,
    DiscordChannel? parentChannel,
    DateTime? now,
  }) {
    final base = computeBase(guild: guild, member: member);
    final permissionChannel = channel.isThread
        ? parentChannel ?? channel
        : channel;
    final permissions =
        DiscordPermissions.has(base, DiscordPermissions.administrator)
        ? DiscordPermissions.all
        : _applyOverwrites(
            base,
            guild: guild,
            channel: permissionChannel,
            member: member,
          );
    if (!member.isTimedOutAt(now ?? DateTime.now().toUtc())) {
      return permissions;
    }
    return permissions &
        (DiscordPermissions.viewChannel |
            DiscordPermissions.readMessageHistory);
  }

  static BigInt _basePermissions(
    DiscordGuild guild,
    DiscordGuildMember member,
  ) {
    if (guild.ownerId == member.user.id) {
      return DiscordPermissions.all;
    }
    var permissions = _rolePermissions(guild.roles, guild.id);
    for (final roleId in member.roleIds) {
      permissions |= _rolePermissions(guild.roles, roleId);
    }
    return permissions;
  }

  static BigInt _applyOverwrites(
    BigInt base, {
    required DiscordGuild guild,
    required DiscordChannel channel,
    required DiscordGuildMember member,
  }) {
    var permissions = base;
    final everyone = _findOverwrite(
      channel.permissionOverwrites,
      guild.id,
      DiscordPermissionOverwriteType.role,
    );
    if (everyone != null) {
      permissions = _apply(permissions, everyone.deny, everyone.allow);
    }

    var roleAllow = BigInt.zero;
    var roleDeny = BigInt.zero;
    for (final overwrite in channel.permissionOverwrites) {
      if (overwrite.type == DiscordPermissionOverwriteType.role &&
          member.roleIds.contains(overwrite.id)) {
        roleAllow |= overwrite.allow;
        roleDeny |= overwrite.deny;
      }
    }
    permissions = _apply(permissions, roleDeny, roleAllow);

    final memberOverwrite = _findOverwrite(
      channel.permissionOverwrites,
      member.user.id,
      DiscordPermissionOverwriteType.member,
    );
    if (memberOverwrite != null) {
      permissions = _apply(
        permissions,
        memberOverwrite.deny,
        memberOverwrite.allow,
      );
    }
    return permissions;
  }
}

BigInt _rolePermissions(List<DiscordRole> roles, String roleId) {
  for (final role in roles) {
    if (role.id == roleId) {
      return role.permissions;
    }
  }
  return BigInt.zero;
}

DiscordPermissionOverwrite? _findOverwrite(
  List<DiscordPermissionOverwrite> overwrites,
  String id,
  DiscordPermissionOverwriteType type,
) {
  for (final overwrite in overwrites) {
    if (overwrite.id == id && overwrite.type == type) {
      return overwrite;
    }
  }
  return null;
}

BigInt _apply(BigInt permissions, BigInt deny, BigInt allow) {
  return (permissions & ~deny) | allow;
}
