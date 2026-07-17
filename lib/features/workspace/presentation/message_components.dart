import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/attachment_video_player.dart';
import 'package:discord_native/features/workspace/presentation/message_actions.dart';
import 'package:discord_native/features/workspace/presentation/discord_message_content.dart';
import 'package:flutter/material.dart';

typedef MessageReactionCallback =
    Future<void> Function(DiscordMessage message, DiscordReaction reaction);
typedef AttachmentVideoBuilder = Widget Function(DiscordAttachment attachment);

class MessageBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final time = message.timestamp.toLocal();
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF5865F2),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.referencedMessage case final referenced?)
                  MessageReplyPreview(message: referenced),
                _MessageHeader(
                  message: message,
                  timeLabel: timeLabel,
                  onReply: onReply,
                  onStartThread: onStartThread,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onTogglePin: onTogglePin,
                ),
                if (message.content.isNotEmpty ||
                    message.embeds.isNotEmpty ||
                    message.stickers.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  DiscordMessageContent(message: message),
                ],
                for (final attachment in message.attachments)
                  MessageAttachmentCard(
                    attachment: attachment,
                    onDownload: onDownloadAttachment,
                  ),
                if (message.reactions.isNotEmpty)
                  MessageReactionList(
                    message: message,
                    reactions: message.reactions,
                    onToggleReaction: onToggleReaction,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.message,
    required this.timeLabel,
    required this.onReply,
    required this.onStartThread,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final DiscordMessage message;
  final String timeLabel;
  final VoidCallback onReply;
  final VoidCallback? onStartThread;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

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
        const Spacer(),
        if (onStartThread != null)
          IconButton(
            tooltip: '스레드 시작',
            visualDensity: VisualDensity.compact,
            onPressed: onStartThread,
            icon: const Icon(
              Icons.forum_outlined,
              size: 18,
              color: Color(0xFFB5BAC1),
            ),
          ),
        IconButton(
          tooltip: '답장',
          visualDensity: VisualDensity.compact,
          onPressed: onReply,
          icon: const Icon(Icons.reply, size: 18, color: Color(0xFFB5BAC1)),
        ),
        if (canEdit || canDelete || onTogglePin != null)
          MessageActionsMenu(
            pinned: message.pinned,
            canEdit: canEdit && onEdit != null,
            canDelete: canDelete && onDelete != null,
            canTogglePin: onTogglePin != null,
            onSelected: (action) {
              switch (action) {
                case MessageAction.edit:
                  onEdit?.call();
                case MessageAction.togglePin:
                  onTogglePin?.call();
                case MessageAction.delete:
                  onDelete?.call();
              }
            },
          ),
      ],
    );
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
