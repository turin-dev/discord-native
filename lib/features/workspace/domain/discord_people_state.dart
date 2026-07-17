import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

enum DiscordPresenceStatus {
  offline,
  online,
  idle,
  dnd;

  factory DiscordPresenceStatus.fromJson(Object? value) {
    return switch (value) {
      'online' => DiscordPresenceStatus.online,
      'idle' => DiscordPresenceStatus.idle,
      'dnd' => DiscordPresenceStatus.dnd,
      _ => DiscordPresenceStatus.offline,
    };
  }
}

enum DiscordRelationshipType {
  none,
  friend,
  blocked,
  incomingRequest,
  outgoingRequest,
  implicit;

  factory DiscordRelationshipType.fromJson(Object? value) {
    return switch (value) {
      1 => DiscordRelationshipType.friend,
      2 => DiscordRelationshipType.blocked,
      3 => DiscordRelationshipType.incomingRequest,
      4 => DiscordRelationshipType.outgoingRequest,
      5 => DiscordRelationshipType.implicit,
      _ => DiscordRelationshipType.none,
    };
  }
}

final class DiscordPresence {
  const DiscordPresence({
    required this.userId,
    required this.status,
    this.guildId,
    this.activityName,
  });

  factory DiscordPresence.fromJson(
    Map<String, Object?> json, {
    String? fallbackGuildId,
  }) {
    final user = _readMap(json['user'], 'presence.user');
    return DiscordPresence(
      userId: _requiredString(user['id'], 'presence.user.id'),
      guildId: _optionalString(json['guild_id']) ?? fallbackGuildId,
      status: DiscordPresenceStatus.fromJson(json['status']),
      activityName: _firstActivityName(json['activities']),
    );
  }

  final String userId;
  final String? guildId;
  final DiscordPresenceStatus status;
  final String? activityName;
}

final class DiscordGuildMember {
  const DiscordGuildMember({
    required this.guildId,
    required this.user,
    required this.roleIds,
    this.nickname,
    this.communicationDisabledUntil,
    this.status = DiscordPresenceStatus.offline,
    this.activityName,
  });

  factory DiscordGuildMember.fromJson(
    Map<String, Object?> json, {
    required String guildId,
    DiscordGuildMember? fallback,
    DiscordPresence? presence,
  }) {
    final userData = _readMap(json['user'], 'member.user');
    return DiscordGuildMember(
      guildId: guildId,
      user: DiscordUser.fromPartialJson(userData, fallback: fallback?.user),
      nickname: json.containsKey('nick')
          ? _optionalString(json['nick'])
          : fallback?.nickname,
      roleIds: json.containsKey('roles')
          ? List.unmodifiable(_readList(json['roles']).whereType<String>())
          : fallback?.roleIds ?? const [],
      communicationDisabledUntil:
          json.containsKey('communication_disabled_until')
          ? _optionalDate(json['communication_disabled_until'])
          : fallback?.communicationDisabledUntil,
      status:
          presence?.status ?? fallback?.status ?? DiscordPresenceStatus.offline,
      activityName: presence?.activityName ?? fallback?.activityName,
    );
  }

  final String guildId;
  final DiscordUser user;
  final String? nickname;
  final List<String> roleIds;
  final DateTime? communicationDisabledUntil;
  final DiscordPresenceStatus status;
  final String? activityName;

  String get displayName => nickname ?? user.displayName ?? user.username;

  bool isTimedOutAt(DateTime time) {
    return communicationDisabledUntil?.isAfter(time.toUtc()) == true;
  }

  DiscordGuildMember withPresence(DiscordPresence presence, DiscordUser user) {
    return DiscordGuildMember(
      guildId: guildId,
      user: user,
      nickname: nickname,
      roleIds: roleIds,
      communicationDisabledUntil: communicationDisabledUntil,
      status: presence.status,
      activityName: presence.activityName,
    );
  }
}

final class DiscordRelationship {
  const DiscordRelationship({
    required this.user,
    required this.type,
    this.nickname,
    this.since,
    this.status = DiscordPresenceStatus.offline,
    this.activityName,
  });

  factory DiscordRelationship.fromJson(
    Map<String, Object?> json, {
    DiscordRelationship? fallback,
    DiscordUser? knownUser,
    DiscordPresence? presence,
  }) {
    final userId = _requiredString(
      json['id'] ?? _optionalMap(json['user'])?['id'],
      'relationship.id',
    );
    final userData = _optionalMap(json['user']);
    final user = userData == null
        ? knownUser ??
              fallback?.user ??
              DiscordUser(id: userId, username: '사용자 $userId')
        : DiscordUser.fromPartialJson(
            userData,
            fallback: knownUser ?? fallback?.user,
          );
    return DiscordRelationship(
      user: user,
      type: DiscordRelationshipType.fromJson(json['type']),
      nickname: json.containsKey('nickname')
          ? _optionalString(json['nickname'])
          : fallback?.nickname,
      since: json.containsKey('since')
          ? _optionalDate(json['since'])
          : fallback?.since,
      status:
          presence?.status ?? fallback?.status ?? DiscordPresenceStatus.offline,
      activityName: presence?.activityName ?? fallback?.activityName,
    );
  }

  final DiscordUser user;
  final DiscordRelationshipType type;
  final String? nickname;
  final DateTime? since;
  final DiscordPresenceStatus status;
  final String? activityName;

  String get displayName => nickname ?? user.displayName ?? user.username;

  DiscordRelationship withPresence(
    DiscordPresence presence,
    DiscordUser nextUser,
  ) {
    return DiscordRelationship(
      user: nextUser,
      type: type,
      nickname: nickname,
      since: since,
      status: presence.status,
      activityName: presence.activityName,
    );
  }

  DiscordRelationship copyWith({DiscordRelationshipType? type}) {
    return DiscordRelationship(
      user: user,
      type: type ?? this.type,
      nickname: nickname,
      since: since,
      status: status,
      activityName: activityName,
    );
  }
}

final class DiscordPeopleState {
  const DiscordPeopleState()
    : _members = const [],
      _relationships = const [],
      _presences = const [],
      _knownUsers = const [];

  const DiscordPeopleState._({
    required List<DiscordGuildMember> members,
    required List<DiscordRelationship> relationships,
    required List<DiscordPresence> presences,
    required List<DiscordUser> knownUsers,
  }) : _members = members,
       _relationships = relationships,
       _presences = presences,
       _knownUsers = knownUsers;

  final List<DiscordGuildMember> _members;
  final List<DiscordRelationship> _relationships;
  final List<DiscordPresence> _presences;
  final List<DiscordUser> _knownUsers;

  List<DiscordRelationship> get friends =>
      _relationshipsOf(DiscordRelationshipType.friend);

  List<DiscordRelationship> get incomingRequests =>
      _relationshipsOf(DiscordRelationshipType.incomingRequest);

  List<DiscordRelationship> get outgoingRequests =>
      _relationshipsOf(DiscordRelationshipType.outgoingRequest);

  List<DiscordRelationship> get blocked =>
      _relationshipsOf(DiscordRelationshipType.blocked);

  List<DiscordGuildMember> membersForGuild(String? guildId) {
    if (guildId == null) {
      return const [];
    }
    final members = _members
        .where((member) => member.guildId == guildId)
        .toList();
    members.sort((left, right) {
      final status = _statusOrder(
        left.status,
      ).compareTo(_statusOrder(right.status));
      return status != 0
          ? status
          : left.displayName.compareTo(right.displayName);
    });
    return List.unmodifiable(members);
  }

  DiscordGuildMember? memberForGuild(String guildId, String userId) {
    return _findMember(_members, guildId, userId);
  }

  DiscordPeopleState setRelationshipType(
    String userId,
    DiscordRelationshipType type,
  ) {
    if (!_relationships.any((relationship) => relationship.user.id == userId)) {
      return this;
    }
    return _copyWith(
      relationships: [
        for (final relationship in _relationships)
          if (relationship.user.id == userId)
            relationship.copyWith(type: type)
          else
            relationship,
      ],
    );
  }

  DiscordPeopleState removeRelationshipById(String userId) {
    if (!_relationships.any((relationship) => relationship.user.id == userId)) {
      return this;
    }
    return _copyWith(
      relationships: _relationships
          .where((relationship) => relationship.user.id != userId)
          .toList(),
    );
  }

  DiscordPeopleState payloadReceived(Map<String, Object?> payload) {
    if (payload['op'] != 0) {
      return this;
    }
    final data = _readMap(payload['d'], 'people dispatch data');
    return switch (payload['t']) {
      'READY' => _receiveReady(data),
      'GUILD_CREATE' => _replaceGuild(data),
      'GUILD_MEMBERS_CHUNK' => _upsertMemberBatch(data),
      'GUILD_MEMBER_LIST_UPDATE' => _receiveMemberList(data),
      'GUILD_MEMBER_ADD' || 'GUILD_MEMBER_UPDATE' => _upsertMember(data),
      'GUILD_MEMBER_REMOVE' => _removeMember(data),
      'PRESENCE_UPDATE' => _updatePresence(data),
      'RELATIONSHIP_ADD' || 'RELATIONSHIP_UPDATE' => _upsertRelationship(data),
      'RELATIONSHIP_REMOVE' => _removeRelationship(data),
      _ => this,
    };
  }

  DiscordPeopleState _receiveReady(Map<String, Object?> data) {
    var knownUsers = <DiscordUser>[];
    for (final channel in _readList(data['private_channels'])) {
      final channelData = _readMap(channel, 'private channel');
      for (final recipient in _readList(channelData['recipients'])) {
        knownUsers = _upsertUser(
          knownUsers,
          DiscordUser.fromJson(_readMap(recipient, 'recipient')),
        );
      }
    }
    final presences = [
      for (final item in _readList(data['presences']))
        DiscordPresence.fromJson(_readMap(item, 'presence')),
    ];
    final relationships = <DiscordRelationship>[];
    for (final item in _readList(data['relationships'])) {
      final relationshipData = _readMap(item, 'relationship');
      final userId = _requiredString(
        relationshipData['id'] ?? _optionalMap(relationshipData['user'])?['id'],
        'relationship.id',
      );
      final relationship = DiscordRelationship.fromJson(
        relationshipData,
        knownUser: _findUser(knownUsers, userId),
        presence: _findPresence(presences, userId, null),
      );
      knownUsers = _upsertUser(knownUsers, relationship.user);
      relationships.add(relationship);
    }
    return DiscordPeopleState._(
      members: const [],
      relationships: List.unmodifiable(relationships),
      presences: List.unmodifiable(presences),
      knownUsers: List.unmodifiable(knownUsers),
    );
  }

  DiscordPeopleState _replaceGuild(Map<String, Object?> data) {
    final guildId = _requiredString(data['id'], 'guild.id');
    final presences = [
      for (final item in _readList(data['presences']))
        DiscordPresence.fromJson(
          _readMap(item, 'presence'),
          fallbackGuildId: guildId,
        ),
    ];
    var knownUsers = _knownUsers;
    final members = <DiscordGuildMember>[];
    for (final item in _readList(data['members'])) {
      final memberData = _readMap(item, 'member');
      final userId = _requiredString(
        _readMap(memberData['user'], 'member.user')['id'],
        'member.user.id',
      );
      final member = DiscordGuildMember.fromJson(
        memberData,
        guildId: guildId,
        presence: _findPresence(presences, userId, guildId),
      );
      knownUsers = _upsertUser(knownUsers, member.user);
      members.add(member);
    }
    return _copyWith(
      members: [
        ..._members.where((member) => member.guildId != guildId),
        ...members,
      ],
      presences: [
        ..._presences.where((presence) => presence.guildId != guildId),
        ...presences,
      ],
      knownUsers: knownUsers,
    );
  }

  DiscordPeopleState _upsertMemberBatch(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'member chunk guild_id');
    var next = this;
    for (final item in _readList(data['members'])) {
      next = next._upsertMember({
        ..._readMap(item, 'member'),
        'guild_id': guildId,
      });
    }
    return next;
  }

  DiscordPeopleState _receiveMemberList(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'member list guild_id');
    var next = this;
    for (final rawOperation in _readList(data['ops'])) {
      final operation = _readMap(rawOperation, 'member list operation');
      for (final rawItem in _readList(operation['items'])) {
        final item = _readMap(rawItem, 'member list item');
        final member = _optionalMap(item['member']);
        if (member != null) {
          next = next._upsertMember({...member, 'guild_id': guildId});
        }
      }
    }
    return next;
  }

  DiscordPeopleState _upsertMember(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'member.guild_id');
    final userData = _readMap(data['user'], 'member.user');
    final userId = _requiredString(userData['id'], 'member.user.id');
    final fallback = _findMember(_members, guildId, userId);
    final member = DiscordGuildMember.fromJson(
      data,
      guildId: guildId,
      fallback: fallback,
      presence: _findPresence(_presences, userId, guildId),
    );
    return _copyWith(
      members: _upsertMemberById(_members, member),
      knownUsers: _upsertUser(_knownUsers, member.user),
    );
  }

  DiscordPeopleState _removeMember(Map<String, Object?> data) {
    final guildId = _requiredString(data['guild_id'], 'member.guild_id');
    final user = _readMap(data['user'], 'member.user');
    final userId = _requiredString(user['id'], 'member.user.id');
    return _copyWith(
      members: _members
          .where(
            (member) => member.guildId != guildId || member.user.id != userId,
          )
          .toList(),
    );
  }

  DiscordPeopleState _updatePresence(Map<String, Object?> data) {
    final presence = DiscordPresence.fromJson(data);
    final fallbackUser = _findUser(_knownUsers, presence.userId);
    final userData = _readMap(data['user'], 'presence.user');
    final user = DiscordUser.fromPartialJson(userData, fallback: fallbackUser);
    final presences = _upsertPresence(_presences, presence);
    return _copyWith(
      presences: presences,
      knownUsers: _upsertUser(_knownUsers, user),
      members: [
        for (final member in _members)
          if (member.user.id == presence.userId &&
              member.guildId == presence.guildId)
            member.withPresence(presence, user)
          else
            member,
      ],
      relationships: [
        for (final relationship in _relationships)
          if (relationship.user.id == presence.userId)
            relationship.withPresence(presence, user)
          else
            relationship,
      ],
    );
  }

  DiscordPeopleState _upsertRelationship(Map<String, Object?> data) {
    final userId = _requiredString(
      data['id'] ?? _optionalMap(data['user'])?['id'],
      'relationship.id',
    );
    final fallback = _findRelationship(_relationships, userId);
    final relationship = DiscordRelationship.fromJson(
      data,
      fallback: fallback,
      knownUser: _findUser(_knownUsers, userId),
      presence: _findPresence(_presences, userId, null),
    );
    return _copyWith(
      relationships: _upsertRelationshipById(_relationships, relationship),
      knownUsers: _upsertUser(_knownUsers, relationship.user),
    );
  }

  DiscordPeopleState _removeRelationship(Map<String, Object?> data) {
    final userId = _requiredString(data['id'], 'relationship.id');
    return _copyWith(
      relationships: _relationships
          .where((relationship) => relationship.user.id != userId)
          .toList(),
    );
  }

  DiscordPeopleState _copyWith({
    List<DiscordGuildMember>? members,
    List<DiscordRelationship>? relationships,
    List<DiscordPresence>? presences,
    List<DiscordUser>? knownUsers,
  }) {
    return DiscordPeopleState._(
      members: List.unmodifiable(members ?? _members),
      relationships: List.unmodifiable(relationships ?? _relationships),
      presences: List.unmodifiable(presences ?? _presences),
      knownUsers: List.unmodifiable(knownUsers ?? _knownUsers),
    );
  }

  List<DiscordRelationship> _relationshipsOf(DiscordRelationshipType type) {
    final relationships =
        _relationships
            .where((relationship) => relationship.type == type)
            .toList()
          ..sort(
            (left, right) => left.displayName.compareTo(right.displayName),
          );
    return List.unmodifiable(relationships);
  }
}

int _statusOrder(DiscordPresenceStatus status) {
  return switch (status) {
    DiscordPresenceStatus.online => 0,
    DiscordPresenceStatus.idle => 1,
    DiscordPresenceStatus.dnd => 2,
    DiscordPresenceStatus.offline => 3,
  };
}

String? _firstActivityName(Object? value) {
  for (final item in _readList(value)) {
    final activity = _readMap(item, 'activity');
    final name = _optionalString(activity['name']);
    if (name != null) {
      return name;
    }
  }
  return null;
}

DiscordPresence? _findPresence(
  List<DiscordPresence> presences,
  String userId,
  String? guildId,
) {
  for (final presence in presences.reversed) {
    if (presence.userId == userId &&
        (guildId == null || presence.guildId == guildId)) {
      return presence;
    }
  }
  return null;
}

DiscordUser? _findUser(List<DiscordUser> users, String userId) {
  for (final user in users) {
    if (user.id == userId) {
      return user;
    }
  }
  return null;
}

DiscordGuildMember? _findMember(
  List<DiscordGuildMember> members,
  String guildId,
  String userId,
) {
  for (final member in members) {
    if (member.guildId == guildId && member.user.id == userId) {
      return member;
    }
  }
  return null;
}

DiscordRelationship? _findRelationship(
  List<DiscordRelationship> relationships,
  String userId,
) {
  for (final relationship in relationships) {
    if (relationship.user.id == userId) {
      return relationship;
    }
  }
  return null;
}

List<DiscordUser> _upsertUser(List<DiscordUser> users, DiscordUser next) {
  return [
    for (final user in users)
      if (user.id == next.id) next else user,
    if (!users.any((user) => user.id == next.id)) next,
  ];
}

List<DiscordGuildMember> _upsertMemberById(
  List<DiscordGuildMember> members,
  DiscordGuildMember next,
) {
  return [
    for (final member in members)
      if (member.guildId == next.guildId && member.user.id == next.user.id)
        next
      else
        member,
    if (!members.any(
      (member) =>
          member.guildId == next.guildId && member.user.id == next.user.id,
    ))
      next,
  ];
}

List<DiscordRelationship> _upsertRelationshipById(
  List<DiscordRelationship> relationships,
  DiscordRelationship next,
) {
  return [
    for (final relationship in relationships)
      if (relationship.user.id == next.user.id) next else relationship,
    if (!relationships.any(
      (relationship) => relationship.user.id == next.user.id,
    ))
      next,
  ];
}

List<DiscordPresence> _upsertPresence(
  List<DiscordPresence> presences,
  DiscordPresence next,
) {
  return [
    for (final presence in presences)
      if (presence.userId == next.userId && presence.guildId == next.guildId)
        next
      else
        presence,
    if (!presences.any(
      (presence) =>
          presence.userId == next.userId && presence.guildId == next.guildId,
    ))
      next,
  ];
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value == null) {
    return null;
  }
  return _readMap(value, 'optional object');
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

DateTime? _optionalDate(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
