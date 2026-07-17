final class DiscordGuildInvite {
  const DiscordGuildInvite({
    required this.code,
    required this.channelId,
    required this.channelName,
    required this.uses,
    required this.maxUses,
    required this.maxAgeSeconds,
    required this.temporary,
    this.inviterName,
    this.createdAt,
    this.expiresAt,
  });

  factory DiscordGuildInvite.fromJson(Map<String, Object?> json) {
    final channel = _readMap(json['channel'], 'invite.channel');
    final inviter = _optionalMap(json['inviter']);
    return DiscordGuildInvite(
      code: _requiredString(json['code'], 'invite.code'),
      channelId: _requiredString(channel['id'], 'invite.channel.id'),
      channelName:
          _optionalString(channel['name']) ??
          '채널 ${_requiredString(channel['id'], 'invite.channel.id')}',
      inviterName: inviter == null
          ? null
          : _optionalString(inviter['global_name']) ??
                _optionalString(inviter['username']),
      uses: _optionalInt(json['uses']) ?? 0,
      maxUses: _optionalInt(json['max_uses']) ?? 0,
      maxAgeSeconds: _optionalInt(json['max_age']) ?? 0,
      temporary: json['temporary'] == true,
      createdAt: _optionalDate(json['created_at']),
      expiresAt: _optionalDate(json['expires_at']),
    );
  }

  final String code;
  final String channelId;
  final String channelName;
  final String? inviterName;
  final int uses;
  final int maxUses;
  final int maxAgeSeconds;
  final bool temporary;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  String get url => 'https://discord.gg/$code';
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

Map<String, Object?>? _optionalMap(Object? value) {
  return value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : null;
}

String _requiredString(Object? value, String field) {
  final normalized = _optionalString(value);
  if (normalized == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return normalized;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? _optionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}

DateTime? _optionalDate(Object? value) {
  return value is String && value.isNotEmpty
      ? DateTime.tryParse(value)?.toUtc()
      : null;
}
