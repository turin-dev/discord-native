import 'package:discord_native/core/network/discord_rest_client.dart';

abstract interface class ClientSyncRepository {
  Future<void> acknowledgeRead(String channelId, String messageId);
}

final class DiscordClientSyncRepository implements ClientSyncRepository {
  const DiscordClientSyncRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<void> acknowledgeRead(String channelId, String messageId) async {
    if (channelId.isEmpty || messageId.isEmpty) {
      throw const FormatException('읽음 동기화 대상이 올바르지 않습니다.');
    }
    await _api.post(
      '/read-states/ack-bulk',
      data: {
        'read_states': [
          {
            'channel_id': channelId,
            'message_id': messageId,
            'read_state_type': 0,
          },
        ],
      },
    );
  }
}
