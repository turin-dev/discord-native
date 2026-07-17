import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordInviteRepository', () {
    test('guild invite 목록과 metadata를 읽는다', () async {
      final api = _FakeDiscordRestApi(
        getResponse: [
          _inviteJson('abc123', 'channel-1'),
          _inviteJson('def456', 'channel-2'),
        ],
      );
      final repository = DiscordInviteRepository(api);

      final invites = await repository.listGuildInvites('guild-1');

      expect(api.lastGetPath, '/guilds/guild-1/invites');
      expect(invites.map((invite) => invite.code), ['abc123', 'def456']);
      expect(invites.first.uses, 2);
      expect(invites.first.maxUses, 10);
      expect(invites.first.expiresAt, DateTime.utc(2026, 7, 18));
    });

    test('invite 생성 입력을 정규화하고 삭제한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: _inviteJson('new123', 'channel-1'),
      );
      final repository = DiscordInviteRepository(api);

      final invite = await repository.createInvite(
        channelId: 'channel-1',
        request: const DiscordInviteRequest(
          maxAgeSeconds: 3600,
          maxUses: 5,
          temporary: true,
          unique: true,
        ),
      );
      await repository.deleteInvite('new123');

      expect(api.lastPostPath, '/channels/channel-1/invites');
      expect(api.lastPostData, {
        'max_age': 3600,
        'max_uses': 5,
        'temporary': true,
        'unique': true,
      });
      expect(api.deletePaths, ['/invites/new123']);
      expect(invite.url, 'https://discord.gg/new123');
    });

    test('잘못된 max age, max uses, ID와 code를 API 전에 거부한다', () {
      final api = _FakeDiscordRestApi();
      final repository = DiscordInviteRepository(api);

      expect(
        () => repository.createInvite(
          channelId: 'channel-1',
          request: const DiscordInviteRequest(maxAgeSeconds: 604801),
        ),
        throwsA(isA<InvalidGuildInviteException>()),
      );
      expect(
        () => repository.createInvite(
          channelId: 'channel-1',
          request: const DiscordInviteRequest(maxUses: 101),
        ),
        throwsA(isA<InvalidGuildInviteException>()),
      );
      expect(
        () => repository.listGuildInvites(' '),
        throwsA(isA<InvalidGuildInviteException>()),
      );
      expect(
        () => repository.deleteInvite(' '),
        throwsA(isA<InvalidGuildInviteException>()),
      );
      expect(api.lastPostPath, isNull);
      expect(api.deletePaths, isEmpty);
    });
  });
}

Map<String, Object?> _inviteJson(String code, String channelId) {
  return {
    'type': 0,
    'code': code,
    'channel': {'id': channelId, 'name': 'general', 'type': 0},
    'inviter': {'id': 'user-1', 'username': 'alice'},
    'uses': 2,
    'max_uses': 10,
    'max_age': 86400,
    'temporary': false,
    'created_at': '2026-07-17T00:00:00.000Z',
    'expires_at': '2026-07-18T00:00:00.000Z',
  };
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi({this.getResponse, this.postResponse});

  final Object? getResponse;
  final Object? postResponse;
  String? lastGetPath;
  String? lastPostPath;
  Object? lastPostData;
  List<String> deletePaths = const [];

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) async {
    lastGetPath = path;
    return getResponse;
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return postResponse;
  }

  @override
  Future<Object?> delete(String path) async {
    deletePaths = List.unmodifiable([...deletePaths, path]);
    return null;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async => null;

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async => null;

  @override
  Future<Object?> put(String path, {Object? data}) async => null;
}
