import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordChannelManagementRepository', () {
    test('text channel 생성 입력을 정규화한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: _channelJson(
          id: 'channel-new',
          name: 'general',
          type: 0,
          topic: '개발 이야기',
        ),
      );
      final repository = DiscordChannelManagementRepository(api);

      final channel = await repository.createChannel(
        guildId: 'guild-1',
        request: const DiscordCreateChannelRequest(
          name: '  general  ',
          type: DiscordGuildChannelType.text,
          topic: '  개발 이야기  ',
          parentId: 'category-1',
          slowmodeSeconds: 5,
          nsfw: true,
        ),
      );

      expect(api.lastPostPath, '/guilds/guild-1/channels');
      expect(api.lastPostData, {
        'name': 'general',
        'type': 0,
        'topic': '개발 이야기',
        'parent_id': 'category-1',
        'rate_limit_per_user': 5,
        'nsfw': true,
      });
      expect(channel.id, 'channel-new');
      expect(channel.topic, '개발 이야기');
      expect(channel.slowmodeSeconds, 5);
      expect(channel.nsfw, isTrue);
    });

    test('forum channel과 tag를 생성한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: _channelJson(
          id: 'forum-new',
          name: '질문',
          type: 15,
          topic: '질문 게시판',
        ),
      );
      final repository = DiscordChannelManagementRepository(api);

      await repository.createChannel(
        guildId: 'guild-1',
        request: const DiscordCreateChannelRequest(
          name: '질문',
          type: DiscordGuildChannelType.forum,
          topic: '질문 게시판',
          availableTags: [
            DiscordForumTagDraft(name: '도움', moderated: false),
            DiscordForumTagDraft(name: '해결됨', moderated: true),
          ],
        ),
      );

      expect(api.lastPostData, {
        'name': '질문',
        'type': 15,
        'topic': '질문 게시판',
        'rate_limit_per_user': 0,
        'nsfw': false,
        'available_tags': [
          {'name': '도움', 'moderated': false},
          {'name': '해결됨', 'moderated': true},
        ],
      });
    });

    test('channel 수정과 삭제 endpoint를 호출한다', () async {
      final api = _FakeDiscordRestApi(
        patchResponse: _channelJson(
          id: 'channel-1',
          name: '공지',
          type: 5,
          topic: '새 공지',
        ),
      );
      final repository = DiscordChannelManagementRepository(api);

      final channel = await repository.updateChannel(
        channelId: 'channel-1',
        guildId: 'guild-1',
        request: const DiscordUpdateChannelRequest(
          name: '  공지  ',
          topic: '  새 공지  ',
          nsfw: false,
          slowmodeSeconds: 10,
        ),
      );
      await repository.deleteChannel('channel-1');

      expect(api.lastPatchPath, '/channels/channel-1');
      expect(api.lastPatchData, {
        'name': '공지',
        'topic': '새 공지',
        'rate_limit_per_user': 10,
        'nsfw': false,
      });
      expect(api.deletePaths, ['/channels/channel-1']);
      expect(channel.name, '공지');
    });

    test('잘못된 이름, topic, slowmode, tag를 API 전에 거부한다', () {
      final api = _FakeDiscordRestApi();
      final repository = DiscordChannelManagementRepository(api);

      for (final request in [
        const DiscordCreateChannelRequest(
          name: ' ',
          type: DiscordGuildChannelType.text,
        ),
        DiscordCreateChannelRequest(
          name: 'general',
          type: DiscordGuildChannelType.text,
          topic: List.filled(1025, 'a').join(),
        ),
        const DiscordCreateChannelRequest(
          name: 'general',
          type: DiscordGuildChannelType.text,
          slowmodeSeconds: 21601,
        ),
        const DiscordCreateChannelRequest(
          name: 'forum',
          type: DiscordGuildChannelType.forum,
          availableTags: [DiscordForumTagDraft(name: '')],
        ),
      ]) {
        expect(
          () => repository.createChannel(guildId: 'guild-1', request: request),
          throwsA(isA<InvalidGuildChannelException>()),
        );
      }
      expect(api.lastPostPath, isNull);
    });
  });
}

Map<String, Object?> _channelJson({
  required String id,
  required String name,
  required int type,
  required String topic,
}) {
  return {
    'id': id,
    'guild_id': 'guild-1',
    'name': name,
    'type': type,
    'position': 0,
    'topic': topic,
    'rate_limit_per_user': type == 0 ? 5 : 0,
    'nsfw': type == 0,
    'permission_overwrites': [],
  };
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi({this.postResponse, this.patchResponse});

  final Object? postResponse;
  final Object? patchResponse;
  String? lastPostPath;
  Object? lastPostData;
  String? lastPatchPath;
  Object? lastPatchData;
  List<String> deletePaths = const [];

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return postResponse;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    lastPatchPath = path;
    lastPatchData = data;
    return patchResponse;
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
