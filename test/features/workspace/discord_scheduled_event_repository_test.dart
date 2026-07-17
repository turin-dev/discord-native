import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordScheduledEventRepository', () {
    test('guild scheduled event 목록을 user count와 함께 읽는다', () async {
      final api = _FakeDiscordRestApi(
        getResponse: [_eventJson('event-1', name: '정기 모임')],
      );
      final repository = DiscordScheduledEventRepository(api);

      final events = await repository.listEvents('guild-1');

      expect(api.lastGetPath, '/guilds/guild-1/scheduled-events');
      expect(api.lastGetQuery, {'with_user_count': true});
      expect(events.single.name, '정기 모임');
      expect(events.single.location, '서울');
      expect(events.single.userCount, 12);
    });

    test('external event 생성·수정·삭제 payload를 보낸다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: _eventJson('event-new', name: '오프라인 모임'),
        patchResponse: _eventJson('event-new', name: '수정된 모임', status: 2),
      );
      final repository = DiscordScheduledEventRepository(api);
      final start = DateTime.utc(2026, 7, 20, 10);
      final end = DateTime.utc(2026, 7, 20, 12);

      final created = await repository.createExternalEvent(
        guildId: 'guild-1',
        request: DiscordExternalEventRequest(
          name: '  오프라인 모임  ',
          description: '  함께 만나요  ',
          location: '  서울  ',
          scheduledStartTime: start,
          scheduledEndTime: end,
        ),
      );
      final updated = await repository.updateExternalEvent(
        guildId: 'guild-1',
        eventId: 'event-new',
        request: DiscordExternalEventRequest(
          name: '수정된 모임',
          description: '함께 만나요',
          location: '서울',
          scheduledStartTime: start,
          scheduledEndTime: end,
        ),
        status: DiscordScheduledEventStatus.active,
      );
      await repository.deleteEvent(guildId: 'guild-1', eventId: 'event-new');

      expect(api.lastPostPath, '/guilds/guild-1/scheduled-events');
      expect(api.lastPostData, {
        'channel_id': null,
        'entity_metadata': {'location': '서울'},
        'name': '오프라인 모임',
        'privacy_level': 2,
        'scheduled_start_time': '2026-07-20T10:00:00.000Z',
        'scheduled_end_time': '2026-07-20T12:00:00.000Z',
        'description': '함께 만나요',
        'entity_type': 3,
      });
      expect(api.lastPatchData, containsPair('status', 2));
      expect(api.deletePaths, ['/guilds/guild-1/scheduled-events/event-new']);
      expect(created.name, '오프라인 모임');
      expect(updated.status, DiscordScheduledEventStatus.active);
    });

    test('잘못된 이름, 위치, 시간 범위를 API 전에 거부한다', () {
      final api = _FakeDiscordRestApi();
      final repository = DiscordScheduledEventRepository(api);
      final start = DateTime.utc(2026, 7, 20, 10);

      for (final request in [
        DiscordExternalEventRequest(
          name: ' ',
          location: '서울',
          scheduledStartTime: start,
          scheduledEndTime: start.add(const Duration(hours: 1)),
        ),
        DiscordExternalEventRequest(
          name: '모임',
          location: ' ',
          scheduledStartTime: start,
          scheduledEndTime: start.add(const Duration(hours: 1)),
        ),
        DiscordExternalEventRequest(
          name: '모임',
          location: '서울',
          scheduledStartTime: start,
          scheduledEndTime: start,
        ),
      ]) {
        expect(
          () => repository.createExternalEvent(
            guildId: 'guild-1',
            request: request,
          ),
          throwsA(isA<InvalidScheduledEventException>()),
        );
      }
      expect(api.lastPostPath, isNull);
    });
  });
}

Map<String, Object?> _eventJson(
  String id, {
  required String name,
  int status = 1,
}) {
  return {
    'id': id,
    'guild_id': 'guild-1',
    'channel_id': null,
    'name': name,
    'description': '함께 만나요',
    'scheduled_start_time': '2026-07-20T10:00:00.000Z',
    'scheduled_end_time': '2026-07-20T12:00:00.000Z',
    'privacy_level': 2,
    'status': status,
    'entity_type': 3,
    'entity_metadata': {'location': '서울'},
    'user_count': 12,
  };
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi({
    this.getResponse,
    this.postResponse,
    this.patchResponse,
  });

  final Object? getResponse;
  final Object? postResponse;
  final Object? patchResponse;
  String? lastGetPath;
  Map<String, Object?>? lastGetQuery;
  String? lastPostPath;
  Object? lastPostData;
  String? lastPatchPath;
  Object? lastPatchData;
  List<String> deletePaths = const [];

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    return getResponse;
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return postResponse;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    lastPatchPath = path;
    lastPatchData = data;
    return patchResponse;
  }

  @override
  Future<Object?> delete(String path) async {
    deletePaths = List.unmodifiable([...deletePaths, path]);
    return null;
  }

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async => null;

  @override
  Future<Object?> put(String path, {Object? data}) async => null;
}
