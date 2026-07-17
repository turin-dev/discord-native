import 'package:discord_native/core/network/discord_rest_client.dart';

abstract interface class RelationshipRepository {
  Future<void> sendFriendRequest(String username);

  Future<void> acceptFriendRequest(String userId);

  Future<void> blockUser(String userId);

  Future<void> removeRelationship(String userId);
}

final class InvalidRelationshipException implements Exception {
  const InvalidRelationshipException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordRelationshipRepository implements RelationshipRepository {
  const DiscordRelationshipRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<void> sendFriendRequest(String username) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw const InvalidRelationshipException('친구의 username을 입력해 주세요.');
    }
    if (normalized.length > 32) {
      throw const InvalidRelationshipException('username은 32자 이하여야 합니다.');
    }
    await _api.post(
      '/users/@me/relationships',
      data: {'username': normalized, 'discriminator': null},
    );
  }

  @override
  Future<void> acceptFriendRequest(String userId) async {
    await _api.put(
      '/users/@me/relationships/$userId',
      data: {'confirm_stranger_request': true},
    );
  }

  @override
  Future<void> blockUser(String userId) async {
    await _api.put('/users/@me/relationships/$userId', data: {'type': 2});
  }

  @override
  Future<void> removeRelationship(String userId) async {
    await _api.delete('/users/@me/relationships/$userId');
  }
}
