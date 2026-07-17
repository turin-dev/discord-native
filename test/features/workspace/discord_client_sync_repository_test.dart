import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_client_sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('현재 사용자의 채널 읽음 상태를 bulk ACK endpoint로 동기화한다', () async {
    final api = _RecordingRestApi();
    final repository = DiscordClientSyncRepository(api);

    await repository.acknowledgeRead('channel-1', 'message-9');

    expect(api.lastPostPath, '/read-states/ack-bulk');
    expect(api.lastPostData, {
      'read_states': [
        {
          'channel_id': 'channel-1',
          'message_id': 'message-9',
          'read_state_type': 0,
        },
      ],
    });
  });
}

final class _RecordingRestApi implements DiscordRestApi {
  String? lastPostPath;
  Object? lastPostData;

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return null;
  }

  @override
  Future<Object?> delete(String path) => throw UnimplementedError();

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) => throw UnimplementedError();

  @override
  Future<Object?> patch(String path, {Object? data}) =>
      throw UnimplementedError();

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) => throw UnimplementedError();

  @override
  Future<Object?> put(String path, {Object? data}) =>
      throw UnimplementedError();
}
