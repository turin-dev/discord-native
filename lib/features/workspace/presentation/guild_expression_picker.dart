import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

sealed class GuildExpressionSelection {
  const GuildExpressionSelection();
}

final class EmojiExpressionSelection extends GuildExpressionSelection {
  const EmojiExpressionSelection(this.text);

  final String text;
}

final class StickerExpressionSelection extends GuildExpressionSelection {
  const StickerExpressionSelection(this.stickerId);

  final String stickerId;
}

Future<GuildExpressionSelection?> showGuildExpressionPicker(
  BuildContext context, {
  required List<DiscordGuildEmoji> emojis,
  required List<DiscordGuildSticker> stickers,
}) {
  return showDialog<GuildExpressionSelection>(
    context: context,
    builder: (context) => DefaultTabController(
      length: 2,
      child: _GuildExpressionDialog(emojis: emojis, stickers: stickers),
    ),
  );
}

class _GuildExpressionDialog extends StatelessWidget {
  const _GuildExpressionDialog({required this.emojis, required this.stickers});

  final List<DiscordGuildEmoji> emojis;
  final List<DiscordGuildSticker> stickers;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이모지·스티커'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '이모지'),
                Tab(text: '스티커'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EmojiPicker(emojis: emojis),
                  _StickerPicker(stickers: stickers),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.emojis});

  final List<DiscordGuildEmoji> emojis;

  @override
  Widget build(BuildContext context) {
    final available = emojis.where((emoji) => emoji.available).toList();
    return GridView.count(
      crossAxisCount: 8,
      padding: const EdgeInsets.all(12),
      children: [
        for (final emoji in _standardEmojis)
          _ExpressionTile(
            key: ValueKey('standard-emoji-$emoji'),
            tooltip: emoji,
            onTap: () =>
                Navigator.pop(context, EmojiExpressionSelection(emoji)),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        for (final emoji in available)
          _ExpressionTile(
            key: ValueKey('guild-emoji-${emoji.id}'),
            tooltip: ':${emoji.name}:',
            onTap: () => Navigator.pop(
              context,
              EmojiExpressionSelection(emoji.messageSyntax),
            ),
            child: CachedNetworkImage(
              imageUrl: emoji.imageUrl,
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              errorWidget: (context, _, _) => Text(':${emoji.name}:'),
            ),
          ),
      ],
    );
  }
}

class _StickerPicker extends StatelessWidget {
  const _StickerPicker({required this.stickers});

  final List<DiscordGuildSticker> stickers;

  @override
  Widget build(BuildContext context) {
    final available = stickers.where((sticker) => sticker.available).toList();
    if (available.isEmpty) {
      return const Center(child: Text('사용 가능한 서버 스티커가 없습니다.'));
    }
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 0.85,
      padding: const EdgeInsets.all(12),
      children: [
        for (final sticker in available)
          _ExpressionTile(
            key: ValueKey('guild-sticker-${sticker.id}'),
            tooltip: sticker.name,
            onTap: () =>
                Navigator.pop(context, StickerExpressionSelection(sticker.id)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StickerPreview(sticker: sticker),
                const SizedBox(height: 6),
                Text(
                  sticker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpressionTile extends StatelessWidget {
  const _ExpressionTile({
    required this.tooltip,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

class _StickerPreview extends StatelessWidget {
  const _StickerPreview({required this.sticker});

  final DiscordGuildSticker sticker;

  @override
  Widget build(BuildContext context) {
    if (sticker.formatType == 3) {
      return Lottie.network(
        'https://cdn.discordapp.com/stickers/${sticker.id}.json',
        width: 110,
        height: 110,
        fit: BoxFit.contain,
        renderCache: RenderCache.raster,
        errorBuilder: (context, _, _) => const Icon(Icons.broken_image),
      );
    }
    final extension = sticker.formatType == 4 ? 'gif' : 'png';
    return CachedNetworkImage(
      imageUrl:
          'https://media.discordapp.net/stickers/${sticker.id}.$extension?size=128',
      width: 110,
      height: 110,
      fit: BoxFit.contain,
      errorWidget: (context, _, _) => const Icon(Icons.broken_image),
    );
  }
}

const List<String> _standardEmojis = [
  '😀',
  '😂',
  '🥰',
  '😎',
  '🤔',
  '😭',
  '😡',
  '🥳',
  '👍',
  '👎',
  '👏',
  '🙏',
  '🔥',
  '🎉',
  '❤️',
  '💯',
  '✅',
  '❌',
  '👀',
  '✨',
  '🚀',
  '💡',
  '🐛',
  '🎮',
];
