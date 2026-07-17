import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

typedef EditMessageCallback =
    Future<void> Function(DiscordMessage message, String content);
typedef MessageActionCallback = Future<void> Function(DiscordMessage message);

enum MessageAction { edit, togglePin, delete }

class MessageActionsMenu extends StatelessWidget {
  const MessageActionsMenu({
    required this.pinned,
    required this.canEdit,
    required this.canDelete,
    required this.canTogglePin,
    required this.onSelected,
    super.key,
  });

  final bool pinned;
  final bool canEdit;
  final bool canDelete;
  final bool canTogglePin;
  final ValueChanged<MessageAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(DiscordColors.sidebar),
      ),
      menuChildren: [
        if (canEdit)
          MenuItemButton(
            onPressed: () => onSelected(MessageAction.edit),
            child: const Text('편집'),
          ),
        if (canTogglePin)
          MenuItemButton(
            onPressed: () => onSelected(MessageAction.togglePin),
            child: Text(pinned ? '고정 해제' : '고정'),
          ),
        if (canDelete)
          MenuItemButton(
            onPressed: () => onSelected(MessageAction.delete),
            child: const Text('삭제'),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        tooltip: '메시지 작업',
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(
          Icons.more_horiz,
          size: 18,
          color: DiscordColors.textMuted,
        ),
      ),
    );
  }
}

Future<String?> showMessageEditDialog(
  BuildContext context,
  DiscordMessage message,
) async {
  var content = message.content;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('메시지 편집'),
      content: TextFormField(
        key: const ValueKey('message-edit-field'),
        initialValue: message.content,
        autofocus: true,
        minLines: 1,
        maxLines: 8,
        maxLength: 2000,
        onChanged: (value) => content = value,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final normalized = content.trim();
            if (normalized.isNotEmpty) {
              Navigator.pop(context, normalized);
            }
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

Future<bool> showMessageDeleteDialog(
  BuildContext context,
  DiscordMessage message,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('메시지 삭제'),
      content: Text(
        message.content.isEmpty
            ? '이 메시지를 삭제할까요?'
            : '"${message.content}" 메시지를 삭제할까요?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
