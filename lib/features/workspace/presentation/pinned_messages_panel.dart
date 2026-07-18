import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_pinned_messages_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_identity.dart';
import 'package:flutter/material.dart';

typedef PinnedMessageCallback = Future<void> Function(DiscordMessage message);

class PinnedMessagesPanel extends StatelessWidget {
  const PinnedMessagesPanel({
    required this.state,
    required this.onSelect,
    required this.onClose,
    required this.onLoadMore,
    required this.onRetry,
    this.onUnpin,
    super.key,
  });

  final DiscordPinnedMessagesState state;
  final PinnedMessageCallback? onSelect;
  final VoidCallback? onClose;
  final Future<void> Function()? onLoadMore;
  final Future<void> Function()? onRetry;
  final PinnedMessageCallback? onUnpin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.discordPalette.sidebar,
      child: SizedBox(
        key: const ValueKey('pinned-messages-panel'),
        width: DiscordLayout.rightPanelWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PinnedMessagesHeader(onClose: onClose),
            if (state.isLoading || state.isLoadingMore)
              const LinearProgressIndicator(minHeight: 2),
            if (state.errorMessage case final message?)
              _PinnedMessagesError(message: message, onRetry: onRetry),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (state.isLoading && state.pins.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.pins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '이 대화에 고정된 메시지가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.discordPalette.textFaint),
          ),
        ),
      );
    }
    final footerCount = state.hasMore ? 1 : 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: state.pins.length + footerCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == state.pins.length) {
          return TextButton(
            key: const ValueKey('load-more-pinned-messages'),
            onPressed: state.isLoadingMore ? null : onLoadMore,
            child: const Text('이전 고정 메시지 더 보기'),
          );
        }
        final pin = state.pins[index];
        return _PinnedMessageCard(
          pin: pin,
          onSelect: onSelect,
          onUnpin: onUnpin,
        );
      },
    );
  }
}

class _PinnedMessagesHeader extends StatelessWidget {
  const _PinnedMessagesHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '고정된 메시지',
              style: TextStyle(
                color: context.discordPalette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: '고정 메시지 닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PinnedMessagesError extends StatelessWidget {
  const _PinnedMessagesError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.discordPalette.danger),
            ),
          ),
          IconButton(
            tooltip: '고정 메시지 다시 불러오기',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _PinnedMessageCard extends StatelessWidget {
  const _PinnedMessageCard({
    required this.pin,
    required this.onSelect,
    required this.onUnpin,
  });

  final DiscordMessagePin pin;
  final PinnedMessageCallback? onSelect;
  final PinnedMessageCallback? onUnpin;

  @override
  Widget build(BuildContext context) {
    final message = pin.message;
    return Material(
      color: context.discordPalette.chat,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        side: BorderSide(color: context.discordPalette.divider),
      ),
      child: InkWell(
        key: ValueKey('pinned-message-${message.id}'),
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        onTap: onSelect == null ? null : () => onSelect!(message),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PinnedMessageAuthor(pin: pin),
              const SizedBox(height: 8),
              _PinnedMessageDetails(message: message, onUnpin: onUnpin),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedMessageDetails extends StatelessWidget {
  const _PinnedMessageDetails({required this.message, required this.onUnpin});

  final DiscordMessage message;
  final PinnedMessageCallback? onUnpin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _messageSummary(message),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.discordPalette.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '메시지로 이동',
              style: TextStyle(
                color: context.discordPalette.brand,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onUnpin != null)
              IconButton(
                tooltip: '고정 해제',
                visualDensity: VisualDensity.compact,
                onPressed: () => onUnpin!(message),
                icon: const Icon(Icons.push_pin, size: 17),
              ),
          ],
        ),
      ],
    );
  }
}

class _PinnedMessageAuthor extends StatelessWidget {
  const _PinnedMessageAuthor({required this.pin});

  final DiscordMessagePin pin;

  @override
  Widget build(BuildContext context) {
    final message = pin.message;
    return Row(
      children: [
        DiscordInitialAvatar(
          id: message.authorId,
          label: message.authorName,
          radius: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          _dateLabel(pin.pinnedAt),
          style: TextStyle(
            color: context.discordPalette.textFaint,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

String _messageSummary(DiscordMessage message) {
  if (message.content.trim().isNotEmpty) {
    return message.content.trim();
  }
  if (message.attachments.isNotEmpty) {
    return '첨부 파일 ${message.attachments.length}개';
  }
  if (message.stickers.isNotEmpty) {
    return '스티커 ${message.stickers.length}개';
  }
  return '(내용 없음)';
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}. ${local.month}. ${local.day}.';
}
