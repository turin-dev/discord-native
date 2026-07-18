import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.enabled,
    required this.replyTarget,
    required this.attachments,
    required this.typingUsers,
    required this.onTyping,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
    required this.onCancelReply,
    required this.onSend,
    required this.hintText,
    this.onPickExpression,
    this.onCreatePoll,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final DiscordMessage? replyTarget;
  final List<DiscordUploadFile> attachments;
  final List<DiscordTypingUser> typingUsers;
  final VoidCallback? onTyping;
  final VoidCallback onPickAttachments;
  final ValueChanged<DiscordUploadFile> onRemoveAttachment;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final String hintText;
  final VoidCallback? onPickExpression;
  final VoidCallback? onCreatePoll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attachments.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final file in attachments)
                  InputChip(
                    label: Text(file.filename),
                    onDeleted: () => onRemoveAttachment(file),
                  ),
              ],
            ),
          if (replyTarget case final target?)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: context.discordPalette.sidebar,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${target.authorName}에게 답장',
                      style: TextStyle(color: context.discordPalette.textMuted),
                    ),
                  ),
                  IconButton(
                    tooltip: '답장 취소',
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          if (typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                _typingLabel(typingUsers),
                style: TextStyle(
                  color: context.discordPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            key: const ValueKey('message-composer-field'),
            controller: controller,
            enabled: enabled,
            onSubmitted: (_) => onSend(),
            onChanged: onTyping == null
                ? null
                : (value) {
                    if (value.trim().isNotEmpty) {
                      onTyping!();
                    }
                  },
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: enabled ? hintText : '채널 연결 대기 중',
              hintStyle: TextStyle(color: context.discordPalette.textFaint),
              filled: true,
              fillColor: context.discordPalette.input,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: replyTarget == null
                    ? const BorderRadius.all(Radius.circular(8))
                    : const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 72),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '이모지·스티커',
                    onPressed: enabled ? onPickExpression : null,
                    icon: const Icon(Icons.emoji_emotions, size: 22),
                  ),
                  IconButton(
                    tooltip: '메시지 보내기',
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              prefixIcon: onCreatePoll == null
                  ? IconButton(
                      tooltip: '파일 첨부',
                      onPressed: enabled ? onPickAttachments : null,
                      icon: const Icon(Icons.add_circle, size: 22),
                    )
                  : PopupMenuButton<_ComposerAddAction>(
                      tooltip: '파일 첨부',
                      enabled: enabled,
                      onSelected: (action) {
                        switch (action) {
                          case _ComposerAddAction.attachment:
                            onPickAttachments();
                          case _ComposerAddAction.poll:
                            onCreatePoll?.call();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ComposerAddAction.attachment,
                          child: ListTile(
                            leading: Icon(Icons.upload_file),
                            title: Text('파일 업로드'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ComposerAddAction.poll,
                          child: ListTile(
                            leading: Icon(Icons.poll_outlined),
                            title: Text('투표 만들기'),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.add_circle, size: 22),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ComposerAddAction { attachment, poll }

String _typingLabel(List<DiscordTypingUser> users) {
  if (users.length == 1) {
    return '${users.single.displayName}님이 입력 중...';
  }
  if (users.length == 2) {
    return '${users[0].displayName}, ${users[1].displayName}님이 입력 중...';
  }
  return '${users.first.displayName} 외 ${users.length - 1}명이 입력 중...';
}
