import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/attachment_video_player.dart';
import 'package:discord_native/features/workspace/presentation/message_actions.dart';
import 'package:discord_native/features/workspace/presentation/discord_message_content.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_identity.dart';
import 'package:flutter/material.dart';

typedef MessageReactionCallback =
    Future<void> Function(DiscordMessage message, DiscordReaction reaction);
typedef AttachmentVideoBuilder = Widget Function(DiscordAttachment attachment);

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.message,
    required this.onReply,
    required this.onToggleReaction,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onDownloadAttachment,
    this.onStartThread,
    super.key,
  });

  final DiscordMessage message;
  final VoidCallback onReply;
  final VoidCallback? onStartThread;
  final MessageReactionCallback? onToggleReaction;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final Future<String?> Function(DiscordAttachment attachment)?
  onDownloadAttachment;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = widget.message.timestamp.toLocal();
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: ValueListenableBuilder(
        valueListenable: _hovered,
        builder: (context, hovered, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            ColoredBox(
              color: hovered ? DiscordColors.hover : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                child: _MessageBody(
                  message: widget.message,
                  timeLabel: timeLabel,
                  onToggleReaction: widget.onToggleReaction,
                  onDownloadAttachment: widget.onDownloadAttachment,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: -14,
              child: IgnorePointer(
                ignoring: !hovered,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: hovered ? 1 : 0,
                  child: _MessageHoverActions(message: widget),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.timeLabel,
    required this.onToggleReaction,
    required this.onDownloadAttachment,
  });

  final DiscordMessage message;
  final String timeLabel;
  final MessageReactionCallback? onToggleReaction;
  final Future<String?> Function(DiscordAttachment attachment)?
  onDownloadAttachment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscordInitialAvatar(id: message.authorId, label: message.authorName),
        const SizedBox(width: 12),
        Expanded(child: _MessageContentColumn(message, timeLabel, this)),
      ],
    );
  }
}

class _MessageContentColumn extends StatelessWidget {
  const _MessageContentColumn(this.message, this.timeLabel, this.owner);

  final DiscordMessage message;
  final String timeLabel;
  final _MessageBody owner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.referencedMessage case final referenced?)
          MessageReplyPreview(message: referenced),
        _MessageHeader(message: message, timeLabel: timeLabel),
        if (message.content.isNotEmpty ||
            message.embeds.isNotEmpty ||
            message.stickers.isNotEmpty) ...[
          const SizedBox(height: 2),
          DiscordMessageContent(message: message),
        ],
        for (final attachment in message.attachments)
          MessageAttachmentCard(
            attachment: attachment,
            onDownload: owner.onDownloadAttachment,
          ),
        if (message.reactions.isNotEmpty)
          MessageReactionList(
            message: message,
            reactions: message.reactions,
            onToggleReaction: owner.onToggleReaction,
          ),
      ],
    );
  }
}

class _MessageHeader extends StatelessWidget {
  const _MessageHeader({required this.message, required this.timeLabel});

  final DiscordMessage message;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          message.authorName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeLabel,
          style: const TextStyle(color: Color(0xFF949BA4), fontSize: 11),
        ),
        if (message.pinned) ...[
          const SizedBox(width: 8),
          const Icon(Icons.push_pin, size: 13, color: Color(0xFFF0B232)),
          const SizedBox(width: 3),
          const Text(
            '고정됨',
            style: TextStyle(color: Color(0xFFF0B232), fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _MessageHoverActions extends StatelessWidget {
  const _MessageHoverActions({required this.message});

  final MessageBubble message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DiscordColors.sidebar,
        border: Border.all(color: DiscordColors.divider),
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.onStartThread != null)
            _HoverAction(
              tooltip: '스레드 시작',
              icon: Icons.forum_outlined,
              onPressed: message.onStartThread!,
            ),
          _HoverAction(
            tooltip: '답장',
            icon: Icons.reply,
            onPressed: message.onReply,
          ),
          if (message.canEdit ||
              message.canDelete ||
              message.onTogglePin != null)
            MessageActionsMenu(
              pinned: message.message.pinned,
              canEdit: message.canEdit && message.onEdit != null,
              canDelete: message.canDelete && message.onDelete != null,
              canTogglePin: message.onTogglePin != null,
              onSelected: (action) => _onAction(message, action),
            ),
        ],
      ),
    );
  }
}

class _HoverAction extends StatelessWidget {
  const _HoverAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: DiscordColors.textMuted),
    );
  }
}

void _onAction(MessageBubble message, MessageAction action) {
  switch (action) {
    case MessageAction.edit:
      message.onEdit?.call();
    case MessageAction.togglePin:
      message.onTogglePin?.call();
    case MessageAction.delete:
      message.onDelete?.call();
  }
}

class MessageReplyPreview extends StatelessWidget {
  const MessageReplyPreview({required this.message, super.key});

  final DiscordMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          const Icon(
            Icons.subdirectory_arrow_right,
            size: 16,
            color: Color(0xFF949BA4),
          ),
          const SizedBox(width: 4),
          Text(
            '${message.authorName}에게 답장',
            style: const TextStyle(
              color: Color(0xFFB5BAC1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message.displayContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF949BA4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageAttachmentCard extends StatelessWidget {
  const MessageAttachmentCard({
    required this.attachment,
    required this.onDownload,
    this.videoBuilder,
    super.key,
  });

  final DiscordAttachment attachment;
  final Future<String?> Function(DiscordAttachment attachment)? onDownload;
  final AttachmentVideoBuilder? videoBuilder;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = attachment.size < 1024 * 1024
        ? '${(attachment.size / 1024).ceil()} KB'
        : '${(attachment.size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        border: Border.all(color: const Color(0xFF1E1F22)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachment.isImage)
            CachedNetworkImage(
              key: ValueKey('attachment-image-${attachment.id}'),
              imageUrl: attachment.proxyUrl,
              width: 420,
              height: 220,
              fit: BoxFit.contain,
              placeholder: (context, _) => const SizedBox(
                height: 120,
                child: Center(
                  child: Icon(Icons.image, color: Color(0xFF949BA4)),
                ),
              ),
              errorWidget: (context, _, _) => const SizedBox(
                height: 80,
                child: Center(
                  child: Icon(Icons.broken_image, color: Color(0xFF949BA4)),
                ),
              ),
            ),
          if (attachment.isVideo)
            (videoBuilder ?? buildDiscordAttachmentVideoPlayer)(attachment),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  attachment.isImage
                      ? Icons.image
                      : attachment.isVideo
                      ? Icons.movie_outlined
                      : Icons.insert_drive_file,
                  color: const Color(0xFF5865F2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00A8FC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        sizeLabel,
                        style: const TextStyle(
                          color: Color(0xFF949BA4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '첨부 파일 다운로드',
                  onPressed: onDownload == null
                      ? null
                      : () => _download(context),
                  icon: const Icon(Icons.download),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      final path = await onDownload?.call(attachment);
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${attachment.filename} 저장 완료')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('첨부 파일 저장에 실패했습니다.')));
      }
    }
  }
}

class MessageReactionList extends StatelessWidget {
  const MessageReactionList({
    required this.message,
    required this.reactions,
    required this.onToggleReaction,
    super.key,
  });

  final DiscordMessage message;
  final List<DiscordReaction> reactions;
  final MessageReactionCallback? onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final reaction in reactions)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleReaction == null
                  ? null
                  : () => onToggleReaction!(message, reaction),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: reaction.me
                      ? const Color(0xFF3C4270)
                      : const Color(0xFF2B2D31),
                  border: Border.all(
                    color: reaction.me
                        ? const Color(0xFF5865F2)
                        : const Color(0xFF3F4147),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${reaction.emojiName} ${reaction.count}',
                    style: const TextStyle(color: Color(0xFFDBDEE1)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
