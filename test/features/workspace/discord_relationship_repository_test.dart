import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_relationship_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordRelationshipRepository', () {
    test('친구 요청 전송 입력을 정규화한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordRelationshipRepository(api);

      await repository.sendFriendRequest('  new.friend  ');

      expect(api.lastPostPath, '/users/@me/relationships');
      expect(api.lastPostData, {
        'username': 'new.friend',
        'discriminator': null,
      });
    });

    test('친구 요청 수락·차단·관계 삭제 endpoint를 호출한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordRelationshipRepository(api);

      await repository.acceptFriendRequest('user-2');
      await repository.blockUser('user-2');
      await repository.removeRelationship('user-2');

      expect(api.putRequests.map((request) => request.path), [
        '/users/@me/relationships/user-2',
        '/users/@me/relationships/user-2',
      ]);
      expect(api.putRequests.first.data, {'confirm_stranger_request': true});
      expect(api.putRequests.last.data, {'type': 2});
      expect(api.deletePaths, ['/users/@me/relationships/user-2']);
    });

    test('빈 username과 32자를 넘는 username을 거부한다', () {
      final api = _FakeDiscordRestApi();
      final repository = DiscordRelationshipRepository(api);

      expect(
        () => repository.sendFriendRequest(' '),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(
        () => repository.sendFriendRequest(List.filled(33, 'a').join()),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(api.lastPostPath, isNull);
    });
  });
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  String? lastPostPath;
  Object? lastPostData;
  List<({String path, Object? data})> putRequests = const [];
  List<String> deletePaths = const [];

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return null;
  }

  @override
  Future<Object?> put(String path, {Object? data}) async {
    putRequests = List.unmodifiable([...putRequests, (path: path, data: data)]);
    return null;
  }

  @override
  Future<Object?> delete(String path) async {
    deletePaths = List.unmodifiable([...deletePaths, path]);
    return null;
  }

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) async => null;

  @override
  Future<Object?> patch(String path, {Object? data}) async => null;

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async => null;
}
