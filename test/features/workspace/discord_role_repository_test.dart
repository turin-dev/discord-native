import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordRoleRepository', () {
    test('role 생성 입력을 현재 colors 형식으로 보낸다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: _roleJson('role-new', '운영진', 1, '8208', 0xFF0000),
      );
      final repository = DiscordRoleRepository(api);

      final role = await repository.createRole(
        guildId: 'guild-1',
        request: DiscordRoleRequest(
          name: '  운영진  ',
          permissions: BigInt.from(8208),
          color: 0xFF0000,
          hoist: true,
          mentionable: true,
        ),
      );

      expect(api.lastPostPath, '/guilds/guild-1/roles');
      expect(api.lastPostData, {
        'name': '운영진',
        'permissions': '8208',
        'colors': {
          'primary_color': 0xFF0000,
          'secondary_color': null,
          'tertiary_color': null,
        },
        'hoist': true,
        'mentionable': true,
      });
      expect(role.name, '운영진');
      expect(role.permissions, BigInt.from(8208));
    });

    test('role 수정·순서 변경·삭제 endpoint를 호출한다', () async {
      final api = _FakeDiscordRestApi(
        patchResponses: [
          _roleJson('role-1', '관리자', 2, '8', 0x00FF00),
          [
            _roleJson('guild-1', '@everyone', 0, '1024', 0),
            _roleJson('role-1', '관리자', 3, '8', 0x00FF00),
          ],
        ],
      );
      final repository = DiscordRoleRepository(api);

      final updated = await repository.updateRole(
        guildId: 'guild-1',
        roleId: 'role-1',
        request: DiscordRoleRequest(
          name: '관리자',
          permissions: BigInt.from(8),
          color: 0x00FF00,
        ),
      );
      final reordered = await repository.updateRolePositions(
        guildId: 'guild-1',
        positions: const {'role-1': 3},
      );
      await repository.deleteRole(guildId: 'guild-1', roleId: 'role-1');

      expect(api.patchRequests.first.path, '/guilds/guild-1/roles/role-1');
      expect(api.patchRequests.last.path, '/guilds/guild-1/roles');
      expect(api.patchRequests.last.data, [
        {'id': 'role-1', 'position': 3},
      ]);
      expect(api.deletePaths, ['/guilds/guild-1/roles/role-1']);
      expect(updated.name, '관리자');
      expect(reordered.last.position, 3);
    });

    test('잘못된 이름, permission, color, position을 API 전에 거부한다', () {
      final api = _FakeDiscordRestApi();
      final repository = DiscordRoleRepository(api);

      expect(
        () => repository.createRole(
          guildId: 'guild-1',
          request: DiscordRoleRequest(name: ' ', permissions: BigInt.zero),
        ),
        throwsA(isA<InvalidGuildRoleException>()),
      );
      expect(
        () => repository.createRole(
          guildId: 'guild-1',
          request: DiscordRoleRequest(name: '역할', permissions: BigInt.from(-1)),
        ),
        throwsA(isA<InvalidGuildRoleException>()),
      );
      expect(
        () => repository.createRole(
          guildId: 'guild-1',
          request: DiscordRoleRequest(
            name: '역할',
            permissions: BigInt.zero,
            color: 0x1000000,
          ),
        ),
        throwsA(isA<InvalidGuildRoleException>()),
      );
      expect(
        () => repository.updateRolePositions(
          guildId: 'guild-1',
          positions: const {'role-1': -1},
        ),
        throwsA(isA<InvalidGuildRoleException>()),
      );
      expect(api.lastPostPath, isNull);
      expect(api.patchRequests, isEmpty);
    });
  });
}

Map<String, Object?> _roleJson(
  String id,
  String name,
  int position,
  String permissions,
  int color,
) {
  return {
    'id': id,
    'name': name,
    'position': position,
    'permissions': permissions,
    'color': color,
    'colors': {
      'primary_color': color,
      'secondary_color': null,
      'tertiary_color': null,
    },
    'hoist': false,
    'managed': false,
    'mentionable': false,
  };
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi({
    this.postResponse,
    List<Object?> patchResponses = const [],
  }) : _patchResponses = List.of(patchResponses);

  final Object? postResponse;
  final List<Object?> _patchResponses;
  String? lastPostPath;
  Object? lastPostData;
  List<({String path, Object? data})> patchRequests = const [];
  List<String> deletePaths = const [];

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return postResponse;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    patchRequests = List.unmodifiable([
      ...patchRequests,
      (path: path, data: data),
    ]);
    return _patchResponses.removeAt(0);
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
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async => null;

  @override
  Future<Object?> put(String path, {Object? data}) async => null;
}
