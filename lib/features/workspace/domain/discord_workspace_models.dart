part of 'discord_workspace_state.dart';

final class DiscordUser {
  const DiscordUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarHash,
  });

  factory DiscordUser.fromJson(Map<String, Object?> json) {
    return DiscordUser(
      id: _requiredString(json['id'], 'user.id'),
      username: _requiredString(json['username'], 'user.username'),
      displayName: _optionalString(json['global_name']),
      avatarHash: _optionalString(json['avatar']),
    );
  }

  factory DiscordUser.fromPartialJson(
    Map<String, Object?> json, {
    DiscordUser? fallback,
  }) {
    final id = _requiredString(json['id'], 'user.id');
    return DiscordUser(
      id: id,
      username:
          _optionalString(json['username']) ?? fallback?.username ?? '사용자 $id',
      displayName: json.containsKey('global_name')
          ? _optionalString(json['global_name'])
          : fallback?.displayName,
      avatarHash: json.containsKey('avatar')
          ? _optionalString(json['avatar'])
          : fallback?.avatarHash,
    );
  }

  final String id;
  final String username;
  final String? displayName;
  final String? avatarHash;

  DiscordUser copyWith({
    String? username,
    Object? displayName = _unset,
    Object? avatarHash = _unset,
  }) {
    return DiscordUser(
      id: id,
      username: username ?? this.username,
      displayName: identical(displayName, _unset)
          ? this.displayName
          : displayName as String?,
      avatarHash: identical(avatarHash, _unset)
          ? this.avatarHash
          : avatarHash as String?,
    );
  }
}

final class DiscordRole {
  const DiscordRole({
    required this.id,
    required this.name,
    required this.position,
    required this.permissions,
    this.color = 0,
    this.hoist = false,
    this.managed = false,
    this.mentionable = false,
  });

  factory DiscordRole.fromJson(Map<String, Object?> json) {
    return DiscordRole(
      id: _requiredString(json['id'], 'role.id'),
      name: _requiredString(json['name'], 'role.name'),
      position: _requiredInt(json['position'], 'role.position'),
      permissions: _permissionValue(json['permissions'], 'role.permissions'),
      color: switch (json['colors']) {
        final Map value =>
          _optionalInt(value['primary_color']) ??
              _optionalInt(json['color']) ??
              0,
        _ => _optionalInt(json['color']) ?? 0,
      },
      hoist: json['hoist'] == true,
      managed: json['managed'] == true,
      mentionable: json['mentionable'] == true,
    );
  }

  final String id;
  final String name;
  final int position;
  final BigInt permissions;
  final int color;
  final bool hoist;
  final bool managed;
  final bool mentionable;
}

final class DiscordGuildEmoji {
  const DiscordGuildEmoji({
    required this.id,
    required this.name,
    this.animated = false,
    this.available = true,
    this.managed = false,
  });

  factory DiscordGuildEmoji.fromJson(Map<String, Object?> json) {
    return DiscordGuildEmoji(
      id: _requiredString(json['id'], 'emoji.id'),
      name: _requiredString(json['name'], 'emoji.name'),
      animated: json['animated'] == true,
      available: json['available'] != false,
      managed: json['managed'] == true,
    );
  }

  final String id;
  final String name;
  final bool animated;
  final bool available;
  final bool managed;

  String get messageSyntax => '<${animated ? 'a' : ''}:$name:$id>';

  String get imageUrl {
    final extension = animated ? 'gif' : 'webp';
    return 'https://cdn.discordapp.com/emojis/$id.$extension?size=96';
  }
}

final class DiscordGuildSticker {
  const DiscordGuildSticker({
    required this.id,
    required this.name,
    required this.formatType,
    this.description,
    this.tags,
    this.available = true,
  });

  factory DiscordGuildSticker.fromJson(Map<String, Object?> json) {
    return DiscordGuildSticker(
      id: _requiredString(json['id'], 'guild sticker.id'),
      name: _requiredString(json['name'], 'guild sticker.name'),
      formatType: _requiredInt(
        json['format_type'],
        'guild sticker.format_type',
      ),
      description: _optionalString(json['description']),
      tags: _optionalString(json['tags']),
      available: json['available'] != false,
    );
  }

  final String id;
  final String name;
  final int formatType;
  final String? description;
  final String? tags;
  final bool available;
}

final class DiscordGuild {
  const DiscordGuild({
    required this.id,
    required this.name,
    this.iconHash,
    this.unavailable = false,
    this.ownerId,
    this.roles = const [],
    this.emojis = const [],
    this.stickers = const [],
  });

  factory DiscordGuild.fromJson(
    Map<String, Object?> json, {
    DiscordGuild? fallback,
  }) {
    final guildData = _guildProperties(json);
    final id = _requiredString(guildData['id'], 'guild.id');
    final roles = guildData.containsKey('roles')
        ? [
            for (final item in _readList(guildData['roles']))
              DiscordRole.fromJson(_readMap(item, 'role')),
          ]
        : fallback?.roles ?? const <DiscordRole>[];
    final emojis = guildData.containsKey('emojis')
        ? [
            for (final item in _readList(guildData['emojis']))
              DiscordGuildEmoji.fromJson(_readMap(item, 'emoji')),
          ]
        : fallback?.emojis ?? const <DiscordGuildEmoji>[];
    final stickers = guildData.containsKey('stickers')
        ? [
            for (final item in _readList(guildData['stickers']))
              DiscordGuildSticker.fromJson(_readMap(item, 'guild sticker')),
          ]
        : fallback?.stickers ?? const <DiscordGuildSticker>[];
    return DiscordGuild(
      id: id,
      name: _optionalString(guildData['name']) ?? fallback?.name ?? '서버 $id',
      iconHash: guildData.containsKey('icon')
          ? _optionalString(guildData['icon'])
          : fallback?.iconHash,
      unavailable: guildData.containsKey('unavailable')
          ? guildData['unavailable'] == true
          : fallback?.unavailable ?? false,
      ownerId: guildData.containsKey('owner_id')
          ? _optionalString(guildData['owner_id'])
          : fallback?.ownerId,
      roles: List.unmodifiable(roles),
      emojis: List.unmodifiable(emojis),
      stickers: List.unmodifiable(stickers),
    );
  }

  final String id;
  final String name;
  final String? iconHash;
  final bool unavailable;
  final String? ownerId;
  final List<DiscordRole> roles;
  final List<DiscordGuildEmoji> emojis;
  final List<DiscordGuildSticker> stickers;

  bool get isDirectMessages => id == discordDirectMessagesGuildId;

  DiscordGuild copyWith({
    List<DiscordRole>? roles,
    List<DiscordGuildEmoji>? emojis,
    List<DiscordGuildSticker>? stickers,
  }) {
    return DiscordGuild(
      id: id,
      name: name,
      iconHash: iconHash,
      unavailable: unavailable,
      ownerId: ownerId,
      roles: List.unmodifiable(roles ?? this.roles),
      emojis: List.unmodifiable(emojis ?? this.emojis),
      stickers: List.unmodifiable(stickers ?? this.stickers),
    );
  }
}

Map<String, Object?> _guildProperties(Map<String, Object?> json) {
  final properties = json['properties'];
  if (properties is! Map) {
    return json;
  }
  return Map.unmodifiable({
    ..._readMap(properties, 'guild.properties'),
    ...json,
  });
}

final class DiscordThreadMetadata {
  const DiscordThreadMetadata({
    required this.archived,
    required this.locked,
    required this.autoArchiveDuration,
    required this.archiveTimestamp,
    this.invitable,
  });

  factory DiscordThreadMetadata.fromJson(Map<String, Object?> json) {
    return DiscordThreadMetadata(
      archived: json['archived'] == true,
      locked: json['locked'] == true,
      autoArchiveDuration: _requiredInt(
        json['auto_archive_duration'],
        'thread_metadata.auto_archive_duration',
      ),
      archiveTimestamp: DateTime.parse(
        _requiredString(
          json['archive_timestamp'],
          'thread_metadata.archive_timestamp',
        ),
      ),
      invitable: json['invitable'] is bool ? json['invitable'] as bool : null,
    );
  }

  final bool archived;
  final bool locked;
  final int autoArchiveDuration;
  final DateTime archiveTimestamp;
  final bool? invitable;
}

enum DiscordPermissionOverwriteType {
  role,
  member;

  factory DiscordPermissionOverwriteType.fromJson(Object? value) {
    return switch (value) {
      0 => DiscordPermissionOverwriteType.role,
      1 => DiscordPermissionOverwriteType.member,
      _ => throw const FormatException(
        'permission overwrite.type 형식이 올바르지 않습니다.',
      ),
    };
  }
}

final class DiscordPermissionOverwrite {
  const DiscordPermissionOverwrite({
    required this.id,
    required this.type,
    required this.allow,
    required this.deny,
  });

  factory DiscordPermissionOverwrite.fromJson(Map<String, Object?> json) {
    return DiscordPermissionOverwrite(
      id: _requiredString(json['id'], 'permission overwrite.id'),
      type: DiscordPermissionOverwriteType.fromJson(json['type']),
      allow: _permissionValue(json['allow'], 'permission overwrite.allow'),
      deny: _permissionValue(json['deny'], 'permission overwrite.deny'),
    );
  }

  final String id;
  final DiscordPermissionOverwriteType type;
  final BigInt allow;
  final BigInt deny;
}

final class DiscordForumTag {
  const DiscordForumTag({
    required this.id,
    required this.name,
    required this.moderated,
    this.emojiId,
    this.emojiName,
  });

  factory DiscordForumTag.fromJson(Map<String, Object?> json) {
    return DiscordForumTag(
      id: _requiredString(json['id'], 'forum tag.id'),
      name: _requiredString(json['name'], 'forum tag.name'),
      moderated: json['moderated'] == true,
      emojiId: _optionalString(json['emoji_id']),
      emojiName: _optionalString(json['emoji_name']),
    );
  }

  final String id;
  final String name;
  final bool moderated;
  final String? emojiId;
  final String? emojiName;
}
