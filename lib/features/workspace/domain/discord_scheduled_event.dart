enum DiscordScheduledEventEntityType {
  stage(1),
  voice(2),
  external(3);

  const DiscordScheduledEventEntityType(this.value);

  factory DiscordScheduledEventEntityType.fromJson(Object? value) {
    return switch (value) {
      1 => DiscordScheduledEventEntityType.stage,
      2 => DiscordScheduledEventEntityType.voice,
      3 => DiscordScheduledEventEntityType.external,
      _ => throw const FormatException(
        'scheduled event.entity_type 형식이 올바르지 않습니다.',
      ),
    };
  }

  final int value;
}

enum DiscordScheduledEventStatus {
  scheduled(1),
  active(2),
  completed(3),
  canceled(4);

  const DiscordScheduledEventStatus(this.value);

  factory DiscordScheduledEventStatus.fromJson(Object? value) {
    return switch (value) {
      1 => DiscordScheduledEventStatus.scheduled,
      2 => DiscordScheduledEventStatus.active,
      3 => DiscordScheduledEventStatus.completed,
      4 => DiscordScheduledEventStatus.canceled,
      _ => throw const FormatException('scheduled event.status 형식이 올바르지 않습니다.'),
    };
  }

  final int value;
}

final class DiscordScheduledEvent {
  const DiscordScheduledEvent({
    required this.id,
    required this.guildId,
    required this.name,
    required this.scheduledStartTime,
    required this.status,
    required this.entityType,
    this.channelId,
    this.description,
    this.scheduledEndTime,
    this.location,
    this.creatorId,
    this.userCount = 0,
  });

  factory DiscordScheduledEvent.fromJson(Map<String, Object?> json) {
    final metadata = _optionalMap(json['entity_metadata']);
    return DiscordScheduledEvent(
      id: _requiredString(json['id'], 'scheduled event.id'),
      guildId: _requiredString(json['guild_id'], 'scheduled event.guild_id'),
      channelId: _optionalString(json['channel_id']),
      creatorId: _optionalString(json['creator_id']),
      name: _requiredString(json['name'], 'scheduled event.name'),
      description: _optionalString(json['description']),
      scheduledStartTime: _requiredDate(
        json['scheduled_start_time'],
        'scheduled event.scheduled_start_time',
      ),
      scheduledEndTime: _optionalDate(json['scheduled_end_time']),
      status: DiscordScheduledEventStatus.fromJson(json['status']),
      entityType: DiscordScheduledEventEntityType.fromJson(json['entity_type']),
      location: _optionalString(metadata?['location']),
      userCount: _optionalInt(json['user_count']) ?? 0,
    );
  }

  final String id;
  final String guildId;
  final String? channelId;
  final String? creatorId;
  final String name;
  final String? description;
  final DateTime scheduledStartTime;
  final DateTime? scheduledEndTime;
  final DiscordScheduledEventStatus status;
  final DiscordScheduledEventEntityType entityType;
  final String? location;
  final int userCount;
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

DateTime _requiredDate(Object? value, String field) {
  final parsed = _optionalDate(value);
  if (parsed == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return parsed;
}

DateTime? _optionalDate(Object? value) {
  return value is String && value.isNotEmpty
      ? DateTime.tryParse(value)?.toUtc()
      : null;
}

int? _optionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}
