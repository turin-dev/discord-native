import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';

const String discordDirectMessagesGuildId = '@me';

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
    final id = _requiredString(json['id'], 'guild.id');
    final roles = json.containsKey('roles')
        ? [
            for (final item in _readList(json['roles']))
              DiscordRole.fromJson(_readMap(item, 'role')),
          ]
        : fallback?.roles ?? const <DiscordRole>[];
    final emojis = json.containsKey('emojis')
        ? [
            for (final item in _readList(json['emojis']))
              DiscordGuildEmoji.fromJson(_readMap(item, 'emoji')),
          ]
        : fallback?.emojis ?? const <DiscordGuildEmoji>[];
    final stickers = json.containsKey('stickers')
        ? [
            for (final item in _readList(json['stickers']))
              DiscordGuildSticker.fromJson(_readMap(item, 'guild sticker')),
          ]
        : fallback?.stickers ?? const <DiscordGuildSticker>[];
    return DiscordGuild(
      id: id,
      name: _optionalString(json['name']) ?? fallback?.name ?? '서버 $id',
      iconHash: json.containsKey('icon')
          ? _optionalString(json['icon'])
          : fallback?.iconHash,
      unavailable: json.containsKey('unavailable')
          ? json['unavailable'] == true
          : fallback?.unavailable ?? false,
      ownerId: json.containsKey('owner_id')
          ? _optionalString(json['owner_id'])
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

final class DiscordChannel {
  const DiscordChannel({
    required this.id,
    required this.guildId,
    required this.name,
    required this.type,
    required this.position,
    this.parentId,
    this.ownerId,
    this.threadMetadata,
    this.joined = false,
    this.recipients = const [],
    this.lastMessageId,
    this.isMessageRequest = false,
    this.permissionOverwrites = const [],
    this.topic,
    this.nsfw = false,
    this.slowmodeSeconds = 0,
    this.availableTags = const [],
    this.appliedTagIds = const [],
  });

  factory DiscordChannel.fromJson(
    Map<String, Object?> json, {
    String? fallbackGuildId,
  }) {
    final type = switch (json['type']) {
      final num value => value.toInt(),
      _ => 0,
    };
    final recipients = [
      for (final item in _readList(json['recipients']))
        DiscordUser.fromJson(_readMap(item, 'channel recipient')),
    ];
    final permissionOverwrites = [
      for (final item in _readList(json['permission_overwrites']))
        DiscordPermissionOverwrite.fromJson(
          _readMap(item, 'permission overwrite'),
        ),
    ];
    final availableTags = [
      for (final item in _readList(json['available_tags']))
        DiscordForumTag.fromJson(_readMap(item, 'forum tag')),
    ];
    return DiscordChannel(
      id: _requiredString(json['id'], 'channel.id'),
      guildId:
          _optionalString(json['guild_id']) ??
          fallbackGuildId ??
          (const {1, 3}.contains(type)
              ? discordDirectMessagesGuildId
              : (throw const FormatException('channel.guild_id가 필요합니다.'))),
      name:
          _optionalString(json['name']) ??
          _privateChannelName(type, recipients),
      type: type,
      position: switch (json['position']) {
        final num value => value.toInt(),
        _ => 0,
      },
      parentId: _optionalString(json['parent_id']),
      ownerId: _optionalString(json['owner_id']),
      threadMetadata: switch (json['thread_metadata']) {
        final Map value => DiscordThreadMetadata.fromJson(
          value.map((key, item) => MapEntry(key.toString(), item)),
        ),
        _ => null,
      },
      joined: json['member'] is Map,
      recipients: List.unmodifiable(recipients),
      lastMessageId: _optionalString(json['last_message_id']),
      isMessageRequest: json['is_message_request'] == true,
      permissionOverwrites: List.unmodifiable(permissionOverwrites),
      topic: _optionalString(json['topic']),
      nsfw: json['nsfw'] == true,
      slowmodeSeconds: _optionalInt(json['rate_limit_per_user']) ?? 0,
      availableTags: List.unmodifiable(availableTags),
      appliedTagIds: List.unmodifiable(
        _readList(json['applied_tags']).whereType<String>(),
      ),
    );
  }

  final String id;
  final String guildId;
  final String name;
  final int type;
  final int position;
  final String? parentId;
  final String? ownerId;
  final DiscordThreadMetadata? threadMetadata;
  final bool joined;
  final List<DiscordUser> recipients;
  final String? lastMessageId;
  final bool isMessageRequest;
  final List<DiscordPermissionOverwrite> permissionOverwrites;
  final String? topic;
  final bool nsfw;
  final int slowmodeSeconds;
  final List<DiscordForumTag> availableTags;
  final List<String> appliedTagIds;

  bool get isPrivate => const {1, 3}.contains(type);

  bool get isCategory => type == 4;

  bool get isThread => const {10, 11, 12}.contains(type);

  bool get isForum => type == 15;

  bool get isMedia => type == 16;

  bool get isArchived => threadMetadata?.archived == true;

  bool get canCreatePublicThread => type == 0;

  bool get canStartThreadFromMessage => const {0, 5}.contains(type);

  bool get isTextChannel =>
      const {0, 1, 3, 5, 10, 11, 12, 15, 16}.contains(type);

  bool get isVoiceChannel => const {2, 13}.contains(type);

  bool get supportsMessageHistory => isTextChannel && !isForum && !isMedia;

  DiscordChannel copyWith({
    String? name,
    DiscordThreadMetadata? threadMetadata,
    bool? joined,
  }) {
    return DiscordChannel(
      id: id,
      guildId: guildId,
      name: name ?? this.name,
      type: type,
      position: position,
      parentId: parentId,
      ownerId: ownerId,
      threadMetadata: threadMetadata ?? this.threadMetadata,
      joined: joined ?? this.joined,
      recipients: recipients,
      lastMessageId: lastMessageId,
      isMessageRequest: isMessageRequest,
      permissionOverwrites: permissionOverwrites,
      topic: topic,
      nsfw: nsfw,
      slowmodeSeconds: slowmodeSeconds,
      availableTags: availableTags,
      appliedTagIds: appliedTagIds,
    );
  }
}

final class DiscordWorkspaceState {
  const DiscordWorkspaceState({
    this.guilds = const [],
    this.channels = const [],
    this.scheduledEvents = const [],
    this.currentUser,
  });

  factory DiscordWorkspaceState.fromCollections({
    List<DiscordGuild> guilds = const [],
    List<DiscordChannel> channels = const [],
    List<DiscordScheduledEvent> scheduledEvents = const [],
    DiscordUser? currentUser,
  }) {
    return DiscordWorkspaceState(
      guilds: List.unmodifiable(guilds),
      channels: List.unmodifiable(_sortChannels(channels)),
      scheduledEvents: List.unmodifiable(_sortScheduledEvents(scheduledEvents)),
      currentUser: currentUser,
    );
  }

  final List<DiscordGuild> guilds;
  final List<DiscordChannel> channels;
  final List<DiscordScheduledEvent> scheduledEvents;
  final DiscordUser? currentUser;

  DiscordWorkspaceState payloadReceived(Map<String, Object?> payload) {
    if (payload['op'] != 0) {
      return this;
    }
    final data = _readMap(payload['d'], 'dispatch data');
    return switch (payload['t']) {
      'READY' => _receiveReady(data),
      'GUILD_CREATE' => _upsertGuild(data, includeChannels: true),
      'GUILD_UPDATE' => _upsertGuild(data),
      'GUILD_DELETE' => _deleteGuild(data),
      'GUILD_ROLE_CREATE' || 'GUILD_ROLE_UPDATE' => _upsertRole(data),
      'GUILD_ROLE_DELETE' => _deleteRole(data),
      'GUILD_EMOJIS_UPDATE' => _replaceGuildEmojis(data),
      'GUILD_STICKERS_UPDATE' => _replaceGuildStickers(data),
      'GUILD_SCHEDULED_EVENT_CREATE' ||
      'GUILD_SCHEDULED_EVENT_UPDATE' => _upsertScheduledEvent(data),
      'GUILD_SCHEDULED_EVENT_DELETE' => _deleteScheduledEvent(data),
      'CHANNEL_CREATE' || 'CHANNEL_UPDATE' => _upsertChannel(data),
      'CHANNEL_DELETE' => _deleteChannel(data),
      'THREAD_CREATE' || 'THREAD_UPDATE' => _upsertChannel(data),
      'THREAD_DELETE' => _deleteChannel(data),
      'THREAD_LIST_SYNC' => _syncThreads(data),
      _ => this,
    };
  }

  List<DiscordChannel> channelsForGuild(String guildId) {
    return List.unmodifiable(
      channels.where((channel) => channel.guildId == guildId),
    );
  }

  List<DiscordScheduledEvent> scheduledEventsForGuild(String guildId) {
    return List.unmodifiable(
      scheduledEvents.where((event) => event.guildId == guildId),
    );
  }

  DiscordChannel? channelById(String channelId) {
    for (final channel in channels) {
      if (channel.id == channelId) {
        return channel;
      }
    }
    return null;
  }

  DiscordWorkspaceState upsertChannels(Iterable<DiscordChannel> nextChannels) {
    var merged = channels;
    for (final channel in nextChannels) {
      merged = _upsertById(merged, channel, (item) => item.id);
    }
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: merged,
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState markThreadJoined(String threadId, bool joined) {
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: [
        for (final channel in channels)
          if (channel.id == threadId)
            channel.copyWith(joined: joined)
          else
            channel,
      ],
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState removeChannel(String channelId) {
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: channels.where((channel) => channel.id != channelId).toList(),
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState upsertRole(String guildId, DiscordRole role) {
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    final roles = _upsertById(guild.roles, role, (item) => item.id)
      ..sort(_compareRoles);
    return _replaceGuildRoles(guild, roles);
  }

  DiscordWorkspaceState replaceRoles(String guildId, List<DiscordRole> roles) {
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    final sorted = List.of(roles)..sort(_compareRoles);
    return _replaceGuildRoles(guild, sorted);
  }

  DiscordWorkspaceState removeRole(String guildId, String roleId) {
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    return _replaceGuildRoles(
      guild,
      guild.roles.where((role) => role.id != roleId).toList(),
    );
  }

  DiscordWorkspaceState _replaceGuildRoles(
    DiscordGuild guild,
    List<DiscordRole> roles,
  ) {
    return DiscordWorkspaceState.fromCollections(
      guilds: _upsertById(
        guilds,
        guild.copyWith(roles: roles),
        (item) => item.id,
      ),
      channels: channels,
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState upsertScheduledEvent(DiscordScheduledEvent event) {
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: channels,
      scheduledEvents: _upsertById(scheduledEvents, event, (item) => item.id),
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState replaceScheduledEvents(
    String guildId,
    List<DiscordScheduledEvent> events,
  ) {
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: channels,
      scheduledEvents: [
        ...scheduledEvents.where((event) => event.guildId != guildId),
        ...events,
      ],
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState removeScheduledEvent(String eventId) {
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: channels,
      scheduledEvents: scheduledEvents
          .where((event) => event.id != eventId)
          .toList(),
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _receiveReady(Map<String, Object?> data) {
    final rawGuilds = _readList(data['guilds']);
    final privateChannels = [
      for (final item in _readList(data['private_channels']))
        DiscordChannel.fromJson(_readMap(item, 'private channel')),
    ];
    final hasDirectMessages =
        privateChannels.isNotEmpty ||
        _readList(data['relationships']).isNotEmpty;
    final userData = _readMap(data['user'], 'READY user');
    return DiscordWorkspaceState.fromCollections(
      guilds: [
        if (hasDirectMessages)
          const DiscordGuild(
            id: discordDirectMessagesGuildId,
            name: '다이렉트 메시지',
          ),
        for (final item in rawGuilds)
          DiscordGuild.fromJson(_readMap(item, 'guild')),
      ],
      channels: privateChannels,
      scheduledEvents: const [],
      currentUser: DiscordUser.fromJson(userData),
    );
  }

  DiscordWorkspaceState _upsertGuild(
    Map<String, Object?> data, {
    bool includeChannels = false,
  }) {
    final guildId = _requiredString(data['id'], 'guild.id');
    final guild = DiscordGuild.fromJson(
      data,
      fallback: _findGuild(guilds, guildId),
    );
    final nextGuilds = _upsertById(guilds, guild, (item) => item.id);
    final withoutGuildChannels = channels
        .where((channel) => channel.guildId != guild.id)
        .toList();
    final nextChannels = includeChannels
        ? [
            ...withoutGuildChannels,
            for (final item in _readList(data['channels']))
              DiscordChannel.fromJson(
                _readMap(item, 'channel'),
                fallbackGuildId: guild.id,
              ),
            for (final item in _readList(data['threads']))
              DiscordChannel.fromJson(
                _readMap(item, 'thread'),
                fallbackGuildId: guild.id,
              ),
          ]
        : channels;
    final nextEvents = includeChannels
        ? [
            ...scheduledEvents.where((event) => event.guildId != guild.id),
            for (final item in _readList(data['guild_scheduled_events']))
              DiscordScheduledEvent.fromJson(_readMap(item, 'scheduled event')),
          ]
        : scheduledEvents;
    return DiscordWorkspaceState.fromCollections(
      guilds: nextGuilds,
      channels: nextChannels,
      scheduledEvents: nextEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _deleteGuild(Map<String, Object?> data) {
    final guildId = _requiredString(data['id'], 'guild.id');
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds.where((guild) => guild.id != guildId).toList(),
      channels: channels
          .where((channel) => channel.guildId != guildId)
          .toList(),
      scheduledEvents: scheduledEvents
          .where((event) => event.guildId != guildId)
          .toList(),
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _upsertRole(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'role event.guild_id');
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    final role = DiscordRole.fromJson(
      _readMap(data['role'], 'role event.role'),
    );
    return upsertRole(guildId, role);
  }

  DiscordWorkspaceState _deleteRole(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'role event.guild_id');
    final roleId = _requiredString(data['role_id'], 'role event.role_id');
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    return removeRole(guildId, roleId);
  }

  DiscordWorkspaceState _replaceGuildEmojis(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'emoji event.guild_id');
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    final emojis = [
      for (final item in _readList(data['emojis']))
        DiscordGuildEmoji.fromJson(_readMap(item, 'emoji')),
    ];
    return _replaceGuild(guild.copyWith(emojis: emojis));
  }

  DiscordWorkspaceState _replaceGuildStickers(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'sticker event.guild_id');
    final guild = _findGuild(guilds, guildId);
    if (guild == null) {
      return this;
    }
    final stickers = [
      for (final item in _readList(data['stickers']))
        DiscordGuildSticker.fromJson(_readMap(item, 'guild sticker')),
    ];
    return _replaceGuild(guild.copyWith(stickers: stickers));
  }

  DiscordWorkspaceState _replaceGuild(DiscordGuild guild) {
    return DiscordWorkspaceState.fromCollections(
      guilds: _upsertById(guilds, guild, (item) => item.id),
      channels: channels,
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _upsertScheduledEvent(Map<String, Object?> data) {
    return upsertScheduledEvent(DiscordScheduledEvent.fromJson(data));
  }

  DiscordWorkspaceState _deleteScheduledEvent(Map<String, Object?> data) {
    final eventId = _requiredString(data['id'], 'scheduled event.id');
    return removeScheduledEvent(eventId);
  }

  DiscordWorkspaceState _upsertChannel(Map<String, Object?> data) {
    final channel = DiscordChannel.fromJson(data);
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: _upsertById(channels, channel, (item) => item.id),
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _deleteChannel(Map<String, Object?> data) {
    final channelId = _requiredString(data['id'], 'channel.id');
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: channels.where((channel) => channel.id != channelId).toList(),
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }

  DiscordWorkspaceState _syncThreads(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'thread sync guild_id');
    final parentIds = _readList(
      data['channel_ids'],
    ).whereType<String>().toSet();
    final nextThreads = [
      for (final item in _readList(data['threads']))
        DiscordChannel.fromJson(
          _readMap(item, 'thread'),
          fallbackGuildId: guildId,
        ),
    ];
    final retained = channels.where((channel) {
      if (!channel.isThread || channel.guildId != guildId) {
        return true;
      }
      return parentIds.isNotEmpty && !parentIds.contains(channel.parentId);
    });
    return DiscordWorkspaceState.fromCollections(
      guilds: guilds,
      channels: [...retained, ...nextThreads],
      scheduledEvents: scheduledEvents,
      currentUser: currentUser,
    );
  }
}

List<T> _upsertById<T>(List<T> items, T next, String Function(T item) idOf) {
  final nextId = idOf(next);
  return [
    for (final item in items)
      if (idOf(item) == nextId) next else item,
    if (!items.any((item) => idOf(item) == nextId)) next,
  ];
}

DiscordGuild? _findGuild(List<DiscordGuild> guilds, String guildId) {
  for (final guild in guilds) {
    if (guild.id == guildId) {
      return guild;
    }
  }
  return null;
}

int _compareRoles(DiscordRole left, DiscordRole right) {
  final position = left.position.compareTo(right.position);
  return position != 0 ? position : left.id.compareTo(right.id);
}

List<DiscordScheduledEvent> _sortScheduledEvents(
  List<DiscordScheduledEvent> events,
) {
  return List.of(events)..sort((left, right) {
    final start = left.scheduledStartTime.compareTo(right.scheduledStartTime);
    return start != 0 ? start : left.id.compareTo(right.id);
  });
}

List<DiscordChannel> _sortChannels(List<DiscordChannel> channels) {
  int comparePosition(DiscordChannel left, DiscordChannel right) {
    if (left.isPrivate && right.isPrivate) {
      return _compareSnowflakesDescending(
        left.lastMessageId ?? left.id,
        right.lastMessageId ?? right.id,
      );
    }
    final position = left.position.compareTo(right.position);
    return position != 0 ? position : left.id.compareTo(right.id);
  }

  final parents = channels.where((channel) => !channel.isThread).toList();
  final categories = parents.where((channel) => channel.isCategory).toList()
    ..sort(comparePosition);
  final categoryIds = categories.map((channel) => channel.id).toSet();
  final uncategorized =
      parents
          .where(
            (channel) =>
                !channel.isCategory &&
                (channel.parentId == null ||
                    !categoryIds.contains(channel.parentId)),
          )
          .toList()
        ..sort(comparePosition);
  final threads = channels.where((channel) => channel.isThread).toList()
    ..sort((left, right) {
      final parent = (left.parentId ?? '').compareTo(right.parentId ?? '');
      if (parent != 0) {
        return parent;
      }
      final archived = left.isArchived == right.isArchived
          ? 0
          : left.isArchived
          ? 1
          : -1;
      return archived != 0 ? archived : left.name.compareTo(right.name);
    });
  final sorted = <DiscordChannel>[];
  void addChannel(DiscordChannel parent) {
    sorted.add(parent);
    sorted.addAll(threads.where((thread) => thread.parentId == parent.id));
  }

  for (final channel in uncategorized) {
    addChannel(channel);
  }
  for (final category in categories) {
    sorted.add(category);
    final children =
        parents.where((channel) => channel.parentId == category.id).toList()
          ..sort(comparePosition);
    for (final child in children) {
      addChannel(child);
    }
  }
  sorted.addAll(
    threads.where(
      (thread) => !parents.any((parent) => parent.id == thread.parentId),
    ),
  );
  return sorted;
}

String _privateChannelName(int type, List<DiscordUser> recipients) {
  if (recipients.isEmpty) {
    return type == 3 ? '그룹 다이렉트 메시지' : '알 수 없는 사용자';
  }
  if (type == 1) {
    final recipient = recipients.first;
    return recipient.displayName ?? recipient.username;
  }
  return recipients
      .take(3)
      .map((user) => user.displayName ?? user.username)
      .join(', ');
}

int _compareSnowflakesDescending(String left, String right) {
  final length = right.length.compareTo(left.length);
  return length != 0 ? length : right.compareTo(left);
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

List<Object?> _readList(Object? value) {
  return value is List ? List.unmodifiable(value) : const [];
}

String _requiredString(Object? value, String field) {
  final string = _optionalString(value);
  if (string == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return string;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int _requiredInt(Object? value, String field) {
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

int? _optionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}

BigInt _permissionValue(Object? value, String field) {
  if (value is String && value.isNotEmpty) {
    try {
      return BigInt.parse(value);
    } on FormatException {
      throw FormatException('$field 형식이 올바르지 않습니다.');
    }
  }
  if (value is num) {
    return BigInt.from(value.toInt());
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

const Object _unset = Object();
