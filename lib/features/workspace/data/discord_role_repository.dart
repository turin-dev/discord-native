import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

final class DiscordRoleRequest {
  const DiscordRoleRequest({
    required this.name,
    required this.permissions,
    this.color = 0,
    this.hoist = false,
    this.mentionable = false,
  });

  final String name;
  final BigInt permissions;
  final int color;
  final bool hoist;
  final bool mentionable;
}

abstract interface class RoleRepository {
  Future<DiscordRole> createRole({
    required String guildId,
    required DiscordRoleRequest request,
  });

  Future<DiscordRole> updateRole({
    required String guildId,
    required String roleId,
    required DiscordRoleRequest request,
  });

  Future<List<DiscordRole>> updateRolePositions({
    required String guildId,
    required Map<String, int> positions,
  });

  Future<void> deleteRole({required String guildId, required String roleId});
}

final class InvalidGuildRoleException implements Exception {
  const InvalidGuildRoleException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordRoleRepository implements RoleRepository {
  const DiscordRoleRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<DiscordRole> createRole({
    required String guildId,
    required DiscordRoleRequest request,
  }) async {
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    final response = await _api.post(
      '/guilds/$normalizedGuildId/roles',
      data: _rolePayload(request),
    );
    return DiscordRole.fromJson(_readMap(response, 'role create response'));
  }

  @override
  Future<DiscordRole> updateRole({
    required String guildId,
    required String roleId,
    required DiscordRoleRequest request,
  }) async {
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    final normalizedRoleId = _requiredId(roleId, 'role ID');
    final response = await _api.patch(
      '/guilds/$normalizedGuildId/roles/$normalizedRoleId',
      data: _rolePayload(request),
    );
    return DiscordRole.fromJson(_readMap(response, 'role update response'));
  }

  @override
  Future<List<DiscordRole>> updateRolePositions({
    required String guildId,
    required Map<String, int> positions,
  }) async {
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    if (positions.isEmpty) {
      throw const InvalidGuildRoleException('변경할 역할 순서가 없습니다.');
    }
    final payload = [
      for (final entry in positions.entries)
        {
          'id': _requiredId(entry.key, 'role ID'),
          'position': _position(entry.value),
        },
    ];
    final response = await _api.patch(
      '/guilds/$normalizedGuildId/roles',
      data: payload,
    );
    return List.unmodifiable([
      for (final item in _readList(response, 'role positions response'))
        DiscordRole.fromJson(_readMap(item, 'role')),
    ]);
  }

  @override
  Future<void> deleteRole({
    required String guildId,
    required String roleId,
  }) async {
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    final normalizedRoleId = _requiredId(roleId, 'role ID');
    await _api.delete('/guilds/$normalizedGuildId/roles/$normalizedRoleId');
  }
}

Map<String, Object?> _rolePayload(DiscordRoleRequest request) {
  final name = request.name.trim();
  if (name.isEmpty || name.length > 100) {
    throw const InvalidGuildRoleException('역할 이름은 1~100자여야 합니다.');
  }
  if (request.permissions.isNegative) {
    throw const InvalidGuildRoleException('역할 permission은 음수일 수 없습니다.');
  }
  if (request.color < 0 || request.color > 0xFFFFFF) {
    throw const InvalidGuildRoleException('역할 색상은 RGB 범위여야 합니다.');
  }
  return {
    'name': name,
    'permissions': request.permissions.toString(),
    'colors': {
      'primary_color': request.color,
      'secondary_color': null,
      'tertiary_color': null,
    },
    'hoist': request.hoist,
    'mentionable': request.mentionable,
  };
}

int _position(int value) {
  if (value < 0) {
    throw const InvalidGuildRoleException('역할 position은 0 이상이어야 합니다.');
  }
  return value;
}

String _requiredId(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw InvalidGuildRoleException('$field가 필요합니다.');
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
