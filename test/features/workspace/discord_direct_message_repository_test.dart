import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_direct_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordDirectMessageRepository', () {
    test('recipient ID로 DM을 열고 channel을 반환한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordDirectMessageRepository(api);

      final channel = await repository.openDirectMessage('user-2');

      expect(api.lastPostPath, '/users/@me/channels');
      expect(api.lastPostData, {'recipient_id': 'user-2'});
      expect(channel.id, 'dm-2');
      expect(channel.name, 'bob');
      expect(channel.recipients.single.id, 'user-2');
    });

    test('빈 recipient ID와 잘못된 응답을 거부한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordDirectMessageRepository(api);

      expect(
        () => repository.openDirectMessage(' '),
        throwsA(isA<InvalidDirectMessageException>()),
      );
      api.response = const [];
      expect(
        () => repository.openDirectMessage('user-2'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  String? lastPostPath;
  Object? lastPostData;
  Object? response = {
    'id': 'dm-2',
    'type': 1,
    'recipients': [
      {'id': 'user-2', 'username': 'bob'},
    ],
  };

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return response;
  }

  @override
  Future<Object?> delete(String path) async => null;

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

  @override
  Future<Object?> put(String path, {Object? data}) async => null;
}
