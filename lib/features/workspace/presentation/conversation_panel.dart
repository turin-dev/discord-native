import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/guild_expression_picker.dart';
import 'package:discord_native/features/workspace/presentation/message_actions.dart';
import 'package:discord_native/features/workspace/presentation/message_composer.dart';
import 'package:discord_native/features/workspace/presentation/message_components.dart';
import 'package:discord_native/features/workspace/presentation/message_pagination_control.dart';
import 'package:discord_native/features/workspace/presentation/poll_composer_dialog.dart';
import 'package:discord_native/features/workspace/presentation/thread_controls.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

export 'package:discord_native/features/workspace/presentation/message_pagination_control.dart'
    show LoadOlderMessagesCallback;

typedef SendMessageCallback = Future<void> Function(String content);
typedef SendPollCallback = Future<void> Function(DiscordPollDraft draft);
typedef SendStickerCallback = Future<void> Function(String stickerId);
typedef SendReplyCallback =
    Future<void> Function(String content, String messageId);
typedef ToggleReactionCallback =
    Future<void> Function(DiscordMessage message, DiscordReaction reaction);
typedef PickAttachmentsCallback = Future<List<DiscordUploadFile>> Function();
typedef DownloadAttachmentCallback =
    Future<String?> Function(DiscordAttachment attachment);
typedef SendAttachmentsCallback =
    Future<void> Function(
      String content,
      List<DiscordUploadFile> files, {
      String? replyToMessageId,
    });

class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    required this.guild,
    required this.channel,
    required this.messageState,
    required this.typingUsers,
    required this.onTyping,
    required this.currentUserId,
    required this.canSendMessages,
    required this.canManageMessages,
    required this.canPinMessages,
    required this.onSendMessage,
    required this.onSendPoll,
    required this.onSendSticker,
    required this.onLoadOlderMessages,
    required this.onSendReply,
    required this.onToggleReaction,
    required this.onVotePoll,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onTogglePinned,
    required this.onPickAttachments,
    required this.onDownloadAttachment,
    required this.onSendAttachments,
    required this.onRefreshThreads,
    required this.onCreateThread,
    required this.onStartThreadFromMessage,
    required this.onJoinThread,
    required this.onSetThreadArchived,
    super.key,
  });

  final DiscordGuild? guild;
  final DiscordChannel? channel;
  final DiscordMessageState messageState;
  final List<DiscordTypingUser> typingUsers;
  final VoidCallback? onTyping;
  final String? currentUserId;
  final bool canSendMessages;
  final bool canManageMessages;
  final bool canPinMessages;
  final SendMessageCallback? onSendMessage;
  final SendPollCallback? onSendPoll;
  final SendStickerCallback? onSendSticker;
  final LoadOlderMessagesCallback? onLoadOlderMessages;
  final SendReplyCallback? onSendReply;
  final ToggleReactionCallback? onToggleReaction;
  final PollVoteCallback? onVotePoll;
  final EditMessageCallback? onEditMessage;
  final MessageActionCallback? onDeleteMessage;
  final MessageActionCallback? onTogglePinned;
  final PickAttachmentsCallback? onPickAttachments;
  final DownloadAttachmentCallback? onDownloadAttachment;
  final SendAttachmentsCallback? onSendAttachments;
  final RefreshThreadsCallback? onRefreshThreads;
  final CreateThreadCallback? onCreateThread;
  final StartThreadFromMessageCallback? onStartThreadFromMessage;
  final JoinThreadCallback? onJoinThread;
  final SetThreadArchivedCallback? onSetThreadArchived;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  final TextEditingController _composer = TextEditingController();
  final ValueNotifier<DiscordMessage?> _replyTarget = ValueNotifier(null);
  final ValueNotifier<List<DiscordUploadFile>> _attachments = ValueNotifier(
    const [],
  );

  @override
  void dispose() {
    _composer.dispose();
    _replyTarget.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    final attachments = _attachments.value;
    if (content.isEmpty && attachments.isEmpty) {
      return;
    }
    if (attachments.isNotEmpty && widget.onSendAttachments != null) {
      await widget.onSendAttachments!(
        content,
        attachments,
        replyToMessageId: _replyTarget.value?.id,
      );
      _composer.clear();
      _attachments.value = const [];
      _replyTarget.value = null;
      return;
    }
    final replyTarget = _replyTarget.value;
    if (replyTarget != null && widget.onSendReply != null) {
      await widget.onSendReply!(content, replyTarget.id);
    } else if (widget.onSendMessage != null) {
      await widget.onSendMessage!(content);
    } else {
      return;
    }
    _composer.clear();
    _replyTarget.value = null;
  }

  Future<void> _pickAttachments() async {
    final picker = widget.onPickAttachments;
    if (picker == null) {
      return;
    }
    final picked = await picker();
    _attachments.value = List.unmodifiable(picked);
  }

  Future<void> _pickExpression() async {
    final guild = widget.guild;
    final selection = await showGuildExpressionPicker(
      context,
      emojis: guild?.emojis ?? const [],
      stickers: guild?.stickers ?? const [],
    );
    switch (selection) {
      case EmojiExpressionSelection(:final text):
        _insertComposerText(text);
      case StickerExpressionSelection(:final stickerId):
        await widget.onSendSticker?.call(stickerId);
      case null:
        return;
    }
  }

  Future<void> _createPoll() async {
    final callback = widget.onSendPoll;
    if (callback == null) {
      return;
    }
    final draft = await showPollComposerDialog(context);
    if (draft != null) {
      await callback(draft);
    }
  }

  void _insertComposerText(String text) {
    final value = _composer.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    final nextText = value.text.replaceRange(start, end, text);
    _composer.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _startThread(DiscordMessage message) async {
    final callback = widget.onStartThreadFromMessage;
    if (callback == null) {
      return;
    }
    final name = await showThreadNameDialog(context, title: '메시지에서 스레드 시작');
    if (name != null) {
      await callback(message.id, name);
    }
  }

  Future<void> _editMessage(DiscordMessage message) async {
    final callback = widget.onEditMessage;
    if (callback == null) {
      return;
    }
    final content = await showMessageEditDialog(context, message);
    if (content != null) {
      await callback(message, content);
    }
  }

  Future<void> _deleteMessage(DiscordMessage message) async {
    final callback = widget.onDeleteMessage;
    if (callback == null) {
      return;
    }
    if (await showMessageDeleteDialog(context, message)) {
      await callback(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ThreadConversationHeader(
          channel: widget.channel,
          onRefreshThreads: widget.onRefreshThreads,
          onCreateThread: widget.onCreateThread,
          onJoinThread: widget.onJoinThread,
          onSetThreadArchived: widget.onSetThreadArchived,
        ),
        Expanded(
          child: _MessageList(
            channel: widget.channel,
            state: widget.messageState,
            currentUserId: widget.currentUserId,
            canManageMessages: widget.canManageMessages,
            onLoadOlderMessages: widget.onLoadOlderMessages,
            onReply: (message) => _replyTarget.value = message,
            onStartThread: widget.channel?.canStartThreadFromMessage == true
                ? _startThread
                : null,
            onToggleReaction: widget.onToggleReaction,
            onVotePoll: widget.onVotePoll,
            onEditMessage: widget.onEditMessage == null ? null : _editMessage,
            onDeleteMessage: widget.onDeleteMessage == null
                ? null
                : _deleteMessage,
            onTogglePinned: widget.canPinMessages
                ? widget.onTogglePinned
                : null,
            onDownloadAttachment: widget.onDownloadAttachment,
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _attachments,
          builder: (context, attachments, _) => ValueListenableBuilder(
            valueListenable: _replyTarget,
            builder: (context, replyTarget, _) => MessageComposer(
              controller: _composer,
              hintText: _composerHint(widget.channel),
              enabled:
                  widget.channel != null &&
                  widget.canSendMessages &&
                  (widget.onSendMessage != null ||
                      widget.onSendPoll != null ||
                      widget.onSendSticker != null ||
                      widget.onSendReply != null ||
                      widget.onSendAttachments != null),
              replyTarget: replyTarget,
              attachments: attachments,
              typingUsers: widget.typingUsers,
              onTyping: widget.onTyping,
              onPickAttachments: _pickAttachments,
              onPickExpression: _pickExpression,
              onCreatePoll: widget.onSendPoll == null ? null : _createPoll,
              onRemoveAttachment: (file) {
                _attachments.value = List.unmodifiable(
                  attachments.where((item) => !identical(item, file)),
                );
              },
              onCancelReply: () => _replyTarget.value = null,
              onSend: _send,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.channel,
    required this.state,
    required this.currentUserId,
    required this.canManageMessages,
    required this.onLoadOlderMessages,
    required this.onReply,
    required this.onStartThread,
    required this.onToggleReaction,
    required this.onVotePoll,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onTogglePinned,
    required this.onDownloadAttachment,
  });

  final DiscordChannel? channel;
  final DiscordMessageState state;
  final String? currentUserId;
  final bool canManageMessages;
  final LoadOlderMessagesCallback? onLoadOlderMessages;
  final ValueChanged<DiscordMessage> onReply;
  final ValueChanged<DiscordMessage>? onStartThread;
  final ToggleReactionCallback? onToggleReaction;
  final PollVoteCallback? onVotePoll;
  final MessageActionCallback? onEditMessage;
  final MessageActionCallback? onDeleteMessage;
  final MessageActionCallback? onTogglePinned;
  final DownloadAttachmentCallback? onDownloadAttachment;

  @override
  Widget build(BuildContext context) {
    if (channel == null) {
      return Center(
        child: Text(
          'Gateway에서 서버와 채널을 기다리고 있습니다.',
          style: TextStyle(color: context.discordPalette.textMuted),
        ),
      );
    }
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Text(
          state.errorMessage!,
          style: TextStyle(color: context.discordPalette.danger),
        ),
      );
    }
    if (state.messages.isEmpty) {
      final selectedChannel = channel!;
      if (selectedChannel.isPrivate) {
        return _DirectMessageEmptyState(channel: selectedChannel);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: context.discordPalette.input,
              child: Icon(
                Icons.tag,
                size: 40,
                color: context.discordPalette.text,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '#${selectedChannel.name}에 오신 것을 환영합니다!',
              style: TextStyle(
                color: context.discordPalette.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '#${selectedChannel.name} 채널의 시작이에요.',
              style: TextStyle(color: context.discordPalette.textMuted),
            ),
          ],
        ),
      );
    }
    final showPagination = state.hasMore || state.isLoadingOlder;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length + (showPagination ? 1 : 0),
      itemBuilder: (context, index) {
        if (showPagination && index == state.messages.length) {
          return OlderMessagesControl(
            isLoading: state.isLoadingOlder,
            errorMessage: state.olderErrorMessage,
            onLoad: onLoadOlderMessages,
          );
        }
        final messageIndex = state.messages.length - 1 - index;
        final message = state.messages[messageIndex];
        final isOwnMessage = currentUserId == message.authorId;
        return MessageBubble(
          message: message,
          onReply: () => onReply(message),
          onStartThread: onStartThread == null
              ? null
              : () => onStartThread!(message),
          onToggleReaction: onToggleReaction,
          onVotePoll: onVotePoll,
          canEdit: isOwnMessage,
          canDelete: isOwnMessage || canManageMessages,
          onEdit: onEditMessage == null ? null : () => onEditMessage!(message),
          onDelete: onDeleteMessage == null
              ? null
              : () => onDeleteMessage!(message),
          onTogglePin: onTogglePinned == null
              ? null
              : () => onTogglePinned!(message),
          onDownloadAttachment: onDownloadAttachment,
        );
      },
    );
  }
}

String _composerHint(DiscordChannel? channel) {
  if (channel == null) {
    return '메시지 보내기';
  }
  return switch (channel.type) {
    1 => '${channel.name}에게 메시지 보내기',
    3 => '${channel.name}에 메시지 보내기',
    _ => '#${channel.name}에 메시지 보내기',
  };
}

class _DirectMessageEmptyState extends StatelessWidget {
  const _DirectMessageEmptyState({required this.channel});

  final DiscordChannel channel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: context.discordPalette.input,
              child: Icon(
                channel.type == 3 ? Icons.group : Icons.person,
                size: 38,
                color: context.discordPalette.text,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              channel.name,
              style: TextStyle(
                color: context.discordPalette.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              channel.type == 3
                  ? '${channel.name} 그룹의 시작이에요.'
                  : '${channel.name}님과 나눈 대화의 시작이에요.',
              style: TextStyle(color: context.discordPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
