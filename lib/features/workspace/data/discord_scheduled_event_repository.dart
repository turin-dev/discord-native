import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';

final class DiscordExternalEventRequest {
  const DiscordExternalEventRequest({
    required this.name,
    required this.location,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    this.description,
  });

  final String name;
  final String? description;
  final String location;
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
}

abstract interface class ScheduledEventRepository {
  Future<List<DiscordScheduledEvent>> listEvents(String guildId);

  Future<DiscordScheduledEvent> createExternalEvent({
    required String guildId,
    required DiscordExternalEventRequest request,
  });

  Future<DiscordScheduledEvent> updateExternalEvent({
    required String guildId,
    required String eventId,
    required DiscordExternalEventRequest request,
    DiscordScheduledEventStatus? status,
  });

  Future<void> deleteEvent({required String guildId, required String eventId});
}

final class InvalidScheduledEventException implements Exception {
  const InvalidScheduledEventException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordScheduledEventRepository
    implements ScheduledEventRepository {
  const DiscordScheduledEventRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<List<DiscordScheduledEvent>> listEvents(String guildId) async {
    final normalizedGuildId = _requiredValue(guildId, 'guild ID');
    final response = await _api.get(
      '/guilds/$normalizedGuildId/scheduled-events',
      queryParameters: const {'with_user_count': true},
    );
    return List.unmodifiable([
      for (final item in _readList(response, 'scheduled events response'))
        DiscordScheduledEvent.fromJson(_readMap(item, 'scheduled event')),
    ]);
  }

  @override
  Future<DiscordScheduledEvent> createExternalEvent({
    required String guildId,
    required DiscordExternalEventRequest request,
  }) async {
    final normalizedGuildId = _requiredValue(guildId, 'guild ID');
    final response = await _api.post(
      '/guilds/$normalizedGuildId/scheduled-events',
      data: _externalPayload(request),
    );
    return DiscordScheduledEvent.fromJson(
      _readMap(response, 'scheduled event create response'),
    );
  }

  @override
  Future<DiscordScheduledEvent> updateExternalEvent({
    required String guildId,
    required String eventId,
    required DiscordExternalEventRequest request,
    DiscordScheduledEventStatus? status,
  }) async {
    final normalizedGuildId = _requiredValue(guildId, 'guild ID');
    final normalizedEventId = _requiredValue(eventId, 'event ID');
    final response = await _api.patch(
      '/guilds/$normalizedGuildId/scheduled-events/$normalizedEventId',
      data: {
        ..._externalPayload(request),
        if (status != null) 'status': status.value,
      },
    );
    return DiscordScheduledEvent.fromJson(
      _readMap(response, 'scheduled event update response'),
    );
  }

  @override
  Future<void> deleteEvent({
    required String guildId,
    required String eventId,
  }) async {
    final normalizedGuildId = _requiredValue(guildId, 'guild ID');
    final normalizedEventId = _requiredValue(eventId, 'event ID');
    await _api.delete(
      '/guilds/$normalizedGuildId/scheduled-events/$normalizedEventId',
    );
  }
}

Map<String, Object?> _externalPayload(DiscordExternalEventRequest request) {
  final name = request.name.trim();
  final location = request.location.trim();
  final description = request.description?.trim();
  if (name.isEmpty || name.length > 100) {
    throw const InvalidScheduledEventException('이벤트 이름은 1~100자여야 합니다.');
  }
  if (location.isEmpty || location.length > 100) {
    throw const InvalidScheduledEventException('이벤트 위치는 1~100자여야 합니다.');
  }
  if (description != null && description.length > 1000) {
    throw const InvalidScheduledEventException('이벤트 설명은 1000자 이하여야 합니다.');
  }
  final start = request.scheduledStartTime.toUtc();
  final end = request.scheduledEndTime.toUtc();
  if (!end.isAfter(start)) {
    throw const InvalidScheduledEventException('이벤트 종료 시각은 시작 이후여야 합니다.');
  }
  return {
    'channel_id': null,
    'entity_metadata': {'location': location},
    'name': name,
    'privacy_level': 2,
    'scheduled_start_time': start.toIso8601String(),
    'scheduled_end_time': end.toIso8601String(),
    if (description != null && description.isNotEmpty)
      'description': description,
    'entity_type': 3,
  };
}

String _requiredValue(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw InvalidScheduledEventException('$field가 필요합니다.');
  }
  return normalized;
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

List<Object?> _readList(Object? value, String field) {
  if (value is List) {
    return List.unmodifiable(value);
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}
