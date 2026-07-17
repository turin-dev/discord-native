import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

abstract interface class DirectMessageRepository {
  Future<DiscordChannel> openDirectMessage(String userId);
}

final class InvalidDirectMessageException implements Exception {
  const InvalidDirectMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordDirectMessageRepository implements DirectMessageRepository {
  const DiscordDirectMessageRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<DiscordChannel> openDirectMessage(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw const InvalidDirectMessageException('DM recipient ID가 필요합니다.');
    }
    final response = await _api.post(
      '/users/@me/channels',
      data: {'recipient_id': normalized},
    );
    if (response is! Map) {
      throw const FormatException('DM channel 응답 형식이 올바르지 않습니다.');
    }
    return DiscordChannel.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
