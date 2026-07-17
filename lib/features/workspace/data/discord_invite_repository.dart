import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_guild_invite.dart';

export 'package:discord_native/features/workspace/domain/discord_guild_invite.dart';

final class DiscordInviteRequest {
  const DiscordInviteRequest({
    this.maxAgeSeconds = 86400,
    this.maxUses = 0,
    this.temporary = false,
    this.unique = false,
  });

  final int maxAgeSeconds;
  final int maxUses;
  final bool temporary;
  final bool unique;
}

abstract interface class InviteRepository {
  Future<List<DiscordGuildInvite>> listGuildInvites(String guildId);

  Future<DiscordGuildInvite> createInvite({
    required String channelId,
    required DiscordInviteRequest request,
  });

  Future<void> deleteInvite(String code);
}

final class InvalidGuildInviteException implements Exception {
  const InvalidGuildInviteException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordInviteRepository implements InviteRepository {
  const DiscordInviteRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<List<DiscordGuildInvite>> listGuildInvites(String guildId) async {
    final normalizedGuildId = _requiredValue(guildId, 'guild ID');
    final response = await _api.get('/guilds/$normalizedGuildId/invites');
    return List.unmodifiable([
      for (final item in _readList(response, 'guild invites response'))
        DiscordGuildInvite.fromJson(_readMap(item, 'invite')),
    ]);
  }

  @override
  Future<DiscordGuildInvite> createInvite({
    required String channelId,
    required DiscordInviteRequest request,
  }) async {
    final normalizedChannelId = _requiredValue(channelId, 'channel ID');
    final response = await _api.post(
      '/channels/$normalizedChannelId/invites',
      data: _requestPayload(request),
    );
    return DiscordGuildInvite.fromJson(
      _readMap(response, 'invite create response'),
    );
  }

  @override
  Future<void> deleteInvite(String code) async {
    final normalizedCode = _requiredValue(code, 'invite code');
    await _api.delete('/invites/$normalizedCode');
  }
}

Map<String, Object?> _requestPayload(DiscordInviteRequest request) {
  if (request.maxAgeSeconds < 0 || request.maxAgeSeconds > 604800) {
    throw const InvalidGuildInviteException('초대 만료 시간은 0~604800초여야 합니다.');
  }
  if (request.maxUses < 0 || request.maxUses > 100) {
    throw const InvalidGuildInviteException('초대 사용 횟수는 0~100이어야 합니다.');
  }
  return {
    'max_age': request.maxAgeSeconds,
    'max_uses': request.maxUses,
    'temporary': request.temporary,
    'unique': request.unique,
  };
}

String _requiredValue(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw InvalidGuildInviteException('$field가 필요합니다.');
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
