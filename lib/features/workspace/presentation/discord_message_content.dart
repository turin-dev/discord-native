import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:markdown/markdown.dart' as md;

class DiscordMessageContent extends StatelessWidget {
  const DiscordMessageContent({required this.message, super.key});

  final DiscordMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.displayContent.isNotEmpty)
          DiscordMarkdownBody(data: message.markdownContent),
        for (var index = 0; index < message.embeds.length; index += 1)
          DiscordEmbedCard(
            key: ValueKey('embed-${message.id}-$index'),
            embed: message.embeds[index],
          ),
        for (final sticker in message.stickers)
          DiscordStickerCard(
            key: ValueKey('sticker-${sticker.id}'),
            sticker: sticker,
          ),
      ],
    );
  }
}

class DiscordMarkdownBody extends StatelessWidget {
  const DiscordMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      inlineSyntaxes: [DiscordSpoilerSyntax()],
      builders: {'discord-spoiler': DiscordSpoilerBuilder()},
      imageBuilder: _buildMarkdownImage,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(color: Color(0xFFDBDEE1), height: 1.35),
        pPadding: EdgeInsets.zero,
        a: const TextStyle(color: Color(0xFF00A8FC)),
        code: const TextStyle(
          color: Color(0xFFE3E5E8),
          backgroundColor: Color(0xFF1E1F22),
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1E1F22),
          border: Border.all(color: const Color(0xFF111214)),
          borderRadius: BorderRadius.circular(4),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF4E5058), width: 3)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 10),
        blockSpacing: 6,
      ),
    );
  }
}

Widget _buildMarkdownImage(Uri uri, String? title, String? alt) {
  final emojiId =
      uri.host == 'cdn.discordapp.com' &&
          uri.pathSegments.length == 2 &&
          uri.pathSegments.first == 'emojis'
      ? uri.pathSegments.last.split('.').first
      : null;
  return CachedNetworkImage(
    key: emojiId == null ? null : ValueKey('custom-emoji-$emojiId'),
    imageUrl: uri.toString(),
    width: emojiId == null ? 320 : 28,
    height: emojiId == null ? 180 : 28,
    fit: BoxFit.contain,
    placeholder: (context, _) => Text(alt ?? ''),
    errorWidget: (context, _, _) => Text(alt ?? '이미지를 불러오지 못했습니다.'),
  );
}

final class DiscordSpoilerSyntax extends md.InlineSyntax {
  DiscordSpoilerSyntax() : super(r'\|\|(.+?)\|\|');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('discord-spoiler', match.group(1)!));
    return true;
  }
}

final class DiscordSpoilerBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return _DiscordSpoiler(
      text: element.textContent,
      style: parentStyle ?? preferredStyle,
    );
  }
}

class _DiscordSpoiler extends StatefulWidget {
  const _DiscordSpoiler({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_DiscordSpoiler> createState() => _DiscordSpoilerState();
}

class _DiscordSpoilerState extends State<_DiscordSpoiler> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(_revealed ? 'spoiler-revealed' : 'spoiler-hidden'),
      borderRadius: BorderRadius.circular(3),
      onTap: () => setState(() => _revealed = true),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _revealed ? const Color(0xFF4E5058) : const Color(0xFF1E1F22),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            _revealed ? widget.text : '스포일러',
            style: widget.style?.copyWith(color: const Color(0xFFDBDEE1)),
          ),
        ),
      ),
    );
  }
}

class DiscordEmbedCard extends StatelessWidget {
  const DiscordEmbedCard({required this.embed, super.key});

  final DiscordEmbed embed;

  @override
  Widget build(BuildContext context) {
    final accent = embed.color == null
        ? const Color(0xFF5865F2)
        : Color(0xFF000000 | embed.color!);
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        border: Border(left: BorderSide(color: accent, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embed.authorName case final author?)
            Text(
              author,
              style: const TextStyle(
                color: Color(0xFFDBDEE1),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (embed.title case final title?) ...[
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF00A8FC),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (embed.description case final description?) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: Color(0xFFDBDEE1))),
          ],
          if (embed.fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final field in embed.fields)
                  SizedBox(
                    width: field.inline ? 140 : 460,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          field.value,
                          style: const TextStyle(color: Color(0xFFDBDEE1)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (embed.image case final image?) ...[
            const SizedBox(height: 8),
            _DiscordRemoteMedia(
              url: image.proxyUrl ?? image.url,
              width: 480,
              height: 240,
            ),
          ],
          if (embed.footerText case final footer?) ...[
            const SizedBox(height: 8),
            Text(
              footer,
              style: const TextStyle(color: Color(0xFF949BA4), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class DiscordStickerCard extends StatelessWidget {
  const DiscordStickerCard({required this.sticker, super.key});

  final DiscordSticker sticker;

  @override
  Widget build(BuildContext context) {
    final extension = sticker.formatType == 4 ? 'gif' : 'png';
    final canRenderImage = sticker.formatType != 3;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sticker.formatType == 3)
            Lottie.network(
              'https://cdn.discordapp.com/stickers/${sticker.id}.json',
              key: ValueKey('sticker-lottie-${sticker.id}'),
              width: 156,
              height: 156,
              fit: BoxFit.contain,
              renderCache: RenderCache.raster,
              errorBuilder: (context, _, _) => const SizedBox(
                width: 156,
                height: 64,
                child: Center(
                  child: Icon(Icons.broken_image, color: Color(0xFF949BA4)),
                ),
              ),
            )
          else if (canRenderImage)
            _DiscordRemoteMedia(
              url:
                  'https://media.discordapp.net/stickers/${sticker.id}.$extension?size=160',
              width: 156,
              height: 156,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_emotions, color: Color(0xFFF0B232)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sticker.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFDBDEE1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscordRemoteMedia extends StatelessWidget {
  const _DiscordRemoteMedia({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      placeholder: (context, _) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: Icon(Icons.image, color: Color(0xFF949BA4))),
      ),
      errorWidget: (context, _, _) => SizedBox(
        width: width,
        height: 64,
        child: const Center(
          child: Icon(Icons.broken_image, color: Color(0xFF949BA4)),
        ),
      ),
    );
  }
}
