import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
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
      height: DiscordLayout.channelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: DiscordColors.chat,
        border: Border(bottom: BorderSide(color: DiscordColors.divider)),
      ),
      child: Row(
        children: [
          Icon(
            selected?.isThread == true ? Icons.forum_outlined : Icons.tag,
            size: 22,
            color: DiscordColors.textFaint,
          ),
          const SizedBox(width: 8),
          Text(
            selected?.name ?? '채널을 선택해 주세요',
            style: DiscordTextStyles.heading,
          ),
          if (selected?.topic case final topic? when topic.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 1,
                height: 22,
                child: ColoredBox(color: DiscordColors.divider),
              ),
            ),
            Expanded(
              child: Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DiscordColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (selected?.canCreatePublicThread == true) ...[
            _HeaderAction(
              tooltip: '스레드 새로고침',
              onPressed: onRefreshThreads == null
                  ? null
                  : () => onRefreshThreads!(selected!.id),
              icon: Icons.refresh,
            ),
            _HeaderAction(
              tooltip: '스레드 만들기',
              onPressed: onCreateThread == null
                  ? null
                  : () => _createThread(context, selected!),
              icon: Icons.add_comment_outlined,
            ),
          ],
          if (selected?.isThread == true) ...[
            if (!selected!.joined && !selected.isArchived)
              _HeaderAction(
                tooltip: '스레드 참여',
                onPressed: onJoinThread == null
                    ? null
                    : () => onJoinThread!(selected.id),
                icon: Icons.login,
              ),
            _HeaderAction(
              tooltip: selected.isArchived ? '스레드 다시 열기' : '스레드 보관',
              onPressed: onSetThreadArchived == null
                  ? null
                  : () =>
                        onSetThreadArchived!(selected.id, !selected.isArchived),
              icon: selected.isArchived
                  ? Icons.unarchive
                  : Icons.archive_outlined,
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: DiscordColors.textMuted),
    );
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
