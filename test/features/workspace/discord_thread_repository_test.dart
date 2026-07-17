import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/data/discord_thread_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordThreadRepository', () {
    test('active와 archived thread를 parent channel 기준으로 합친다', () async {
      final api = _FakeDiscordRestApi({
        '/guilds/guild-1/threads/active': {
          'threads': [
            _threadJson('thread-active', 'channel-1', archived: false),
            _threadJson('thread-other', 'channel-2', archived: false),
          ],
          'members': [],
        },
        '/channels/channel-1/threads/archived/public': {
          'threads': [
            _threadJson('thread-public', 'channel-1', archived: true),
          ],
          'members': [],
          'has_more': false,
        },
        '/channels/channel-1/users/@me/threads/archived/private': {
          'threads': [
            _threadJson(
              'thread-private',
              'channel-1',
              type: 12,
              archived: true,
            ),
          ],
          'members': [
            {'id': 'thread-private', 'user_id': 'user-1'},
          ],
          'has_more': false,
        },
      });
      final repository = DiscordThreadRepository(api);

      final threads = await repository.listThreads(
        guildId: 'guild-1',
        parentChannelId: 'channel-1',
      );

      expect(threads.map((thread) => thread.id), [
        'thread-active',
        'thread-private',
        'thread-public',
      ]);
      expect(threads.where((thread) => thread.isArchived), hasLength(2));
      expect(
        threads.singleWhere((thread) => thread.id == 'thread-private').joined,
        isTrue,
      );
    });

    test('공개 thread 생성 입력을 정규화하고 명시적 type을 보낸다', () async {
      final api = _FakeDiscordRestApi(
        const {},
        postResponse: _threadJson('thread-new', 'channel-1', archived: false),
      );
      final repository = DiscordThreadRepository(api);

      final thread = await repository.createPublicThread(
        guildId: 'guild-1',
        parentChannelId: 'channel-1',
        name: '  설계 토론  ',
      );

      expect(api.lastPostPath, '/channels/channel-1/threads');
      expect(api.lastPostData, {
        'name': '설계 토론',
        'type': 11,
        'auto_archive_duration': 1440,
      });
      expect(thread.id, 'thread-new');
    });

    test('메시지에서 thread를 시작하고 참여·보관 상태를 변경한다', () async {
      final api = _FakeDiscordRestApi(
        const {},
        postResponse: _threadJson(
          'thread-message',
          'channel-1',
          archived: false,
        ),
        patchResponse: _threadJson(
          'thread-message',
          'channel-1',
          archived: true,
        ),
      );
      final repository = DiscordThreadRepository(api);

      await repository.startThreadFromMessage(
        guildId: 'guild-1',
        channelId: 'channel-1',
        messageId: 'message-1',
        name: '원문 토론',
      );
      await repository.joinThread('thread-message');
      final archived = await repository.setArchived(
        guildId: 'guild-1',
        threadId: 'thread-message',
        archived: true,
      );

      expect(
        api.lastPostPath,
        '/channels/channel-1/messages/message-1/threads',
      );
      expect(api.putPaths, ['/channels/thread-message/thread-members/@me']);
      expect(api.lastPatchPath, '/channels/thread-message');
      expect(api.lastPatchData, {'archived': true});
      expect(archived.isArchived, isTrue);
    });

    test('forum post 제목·본문·tag를 새 thread 요청으로 보낸다', () async {
      final api = _FakeDiscordRestApi(
        const {},
        postResponse: {
          ..._threadJson('post-new', 'forum-1', archived: false),
          'message': {'id': 'message-1', 'content': '질문 본문'},
          'applied_tags': ['tag-1'],
        },
      );
      final repository = DiscordThreadRepository(api);

      final post = await repository.createForumPost(
        guildId: 'guild-1',
        forumChannelId: 'forum-1',
        title: '  질문 제목  ',
        content: '  질문 본문  ',
        appliedTagIds: const ['tag-1'],
      );

      expect(api.lastPostPath, '/channels/forum-1/threads');
      expect(api.lastPostData, {
        'name': '질문 제목',
        'auto_archive_duration': 1440,
        'message': {'content': '질문 본문'},
        'applied_tags': ['tag-1'],
      });
      expect(post.id, 'post-new');
      expect(post.appliedTagIds, ['tag-1']);
    });

    test('빈 이름과 100자를 넘는 이름은 API 전에 거부한다', () async {
      final api = _FakeDiscordRestApi(const {});
      final repository = DiscordThreadRepository(api);

      expect(
        () => repository.createPublicThread(
          guildId: 'guild-1',
          parentChannelId: 'channel-1',
          name: ' ',
        ),
        throwsA(isA<InvalidThreadException>()),
      );
      expect(
        () => repository.createPublicThread(
          guildId: 'guild-1',
          parentChannelId: 'channel-1',
          name: List.filled(101, 'a').join(),
        ),
        throwsA(isA<InvalidThreadException>()),
      );
      expect(api.lastPostPath, isNull);
    });

    test('forum post의 빈 본문과 5개를 넘는 tag를 거부한다', () {
      final api = _FakeDiscordRestApi(const {});
      final repository = DiscordThreadRepository(api);

      expect(
        () => repository.createForumPost(
          guildId: 'guild-1',
          forumChannelId: 'forum-1',
          title: '질문',
          content: ' ',
        ),
        throwsA(isA<InvalidThreadException>()),
      );
      expect(
        () => repository.createForumPost(
          guildId: 'guild-1',
          forumChannelId: 'forum-1',
          title: '질문',
          content: '본문',
          appliedTagIds: const ['1', '2', '3', '4', '5', '6'],
        ),
        throwsA(isA<InvalidThreadException>()),
      );
    });
  });
}

Map<String, Object?> _threadJson(
  String id,
  String parentId, {
  int type = 11,
  required bool archived,
}) {
  return {
    'id': id,
    'guild_id': 'guild-1',
    'parent_id': parentId,
    'name': id,
    'type': type,
    'position': 0,
    'thread_metadata': {
      'archived': archived,
      'locked': false,
      'auto_archive_duration': 1440,
      'archive_timestamp': '2026-07-16T10:00:00.000Z',
    },
  };
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi(
    this.getResponses, {
    this.postResponse,
    this.patchResponse,
  });

  final Map<String, Object?> getResponses;
  final Object? postResponse;
  final Object? patchResponse;
  String? lastPostPath;
  Object? lastPostData;
  String? lastPatchPath;
  Object? lastPatchData;
  List<String> putPaths = const [];

  @override
  Future<Object?> delete(String path) async => null;

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) async {
    return getResponses[path];
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    lastPatchPath = path;
    lastPatchData = data;
    return patchResponse;
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return postResponse;
  }

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async {
    return null;
  }

  @override
  Future<Object?> put(String path, {Object? data}) async {
    putPaths = List.unmodifiable([...putPaths, path]);
    return null;
  }
}
