import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';

typedef RefreshThreadsCallback = Future<void> Function(String parentChannelId);
typedef CreateThreadCallback =
    Future<void> Function(String parentChannelId, String name);
typedef StartThreadFromMessageCallback =
    Future<void> Function(String messageId, String name);
typedef JoinThreadCallback = Future<void> Function(String threadId);
typedef SetThreadArchivedCallback =
    Future<void> Function(String threadId, bool archived);

class ThreadConversationHeader extends StatelessWidget {
  const ThreadConversationHeader({
    required this.channel,
    this.onRefreshThreads,
    this.onCreateThread,
    this.onJoinThread,
    this.onSetThreadArchived,
    super.key,
  });

  final DiscordChannel? channel;
  final RefreshThreadsCallback? onRefreshThreads;
  final CreateThreadCallback? onCreateThread;
  final JoinThreadCallback? onJoinThread;
  final SetThreadArchivedCallback? onSetThreadArchived;

  @override
  Widget build(BuildContext context) {
    final selected = channel;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF26272B))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected == null
                  ? '채널을 선택해 주세요'
                  : '${selected.isThread ? '›' : '#'} ${selected.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected?.canCreatePublicThread == true) ...[
            IconButton(
              tooltip: '스레드 새로고침',
              onPressed: onRefreshThreads == null
                  ? null
                  : () => onRefreshThreads!(selected!.id),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '스레드 만들기',
              onPressed: onCreateThread == null
                  ? null
                  : () => _createThread(context, selected!),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
          if (selected?.isThread == true) ...[
            if (!selected!.joined && !selected.isArchived)
              IconButton(
                tooltip: '스레드 참여',
                onPressed: onJoinThread == null
                    ? null
                    : () => onJoinThread!(selected.id),
                icon: const Icon(Icons.login),
              ),
            IconButton(
              tooltip: selected.isArchived ? '스레드 다시 열기' : '스레드 보관',
              onPressed: onSetThreadArchived == null
                  ? null
                  : () =>
                        onSetThreadArchived!(selected.id, !selected.isArchived),
              icon: Icon(
                selected.isArchived ? Icons.unarchive : Icons.archive_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createThread(
    BuildContext context,
    DiscordChannel selected,
  ) async {
    final name = await showThreadNameDialog(context, title: '새 스레드');
    if (name != null) {
      await onCreateThread!(selected.id, name);
    }
  }
}

Future<String?> showThreadNameDialog(
  BuildContext context, {
  required String title,
}) async {
  var value = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('thread-name-field'),
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '스레드 이름'),
        onChanged: (next) => value = next,
        onSubmitted: (value) {
          final normalized = value.trim();
          if (normalized.isNotEmpty) {
            Navigator.of(context).pop(normalized);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final normalized = value.trim();
            if (normalized.isNotEmpty) {
              Navigator.of(context).pop(normalized);
            }
          },
          child: const Text('만들기'),
        ),
      ],
    ),
  );
}
