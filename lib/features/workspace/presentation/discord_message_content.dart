import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/message_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:markdown/markdown.dart' as md;

class DiscordMessageContent extends StatelessWidget {
  const DiscordMessageContent({
    required this.message,
    this.mediaProxyUrls = const {},
    this.onVotePoll,
    super.key,
  });

  final DiscordMessage message;
  final Map<String, String> mediaProxyUrls;
  final PollVoteCallback? onVotePoll;

  @override
  Widget build(BuildContext context) {
    final mediaLinks = _discordMediaLinks(
      message.markdownContent,
      mediaProxyUrls,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.displayContent.isNotEmpty)
          DiscordMarkdownBody(
            data: _markdownWithMediaFileNames(
              message.markdownContent,
              mediaLinks,
            ),
          ),
        for (var index = 0; index < mediaLinks.length; index += 1)
          _DiscordMediaLinkPreview(
            key: ValueKey('discord-media-link-${message.id}-$index'),
            link: mediaLinks[index],
          ),
        if (message.poll case final poll?)
          DiscordPollCard(
            key: ValueKey('poll-${message.id}'),
            poll: poll,
            onSelectAnswer: onVotePoll == null
                ? null
                : (answerId) => onVotePoll!(message, answerId),
          ),
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

final class _DiscordMediaLink {
  const _DiscordMediaLink({
    required this.start,
    required this.end,
    required this.uri,
    required this.mediaUri,
    required this.fileName,
  });

  final int start;
  final int end;
  final Uri uri;
  final Uri mediaUri;
  final String fileName;
}

class _DiscordMediaLinkPreview extends StatelessWidget {
  const _DiscordMediaLinkPreview({required this.link, super.key});

  final _DiscordMediaLink link;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: CachedNetworkImage(
        imageUrl: link.mediaUri.toString(),
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(
          width: 400,
          height: 200,
          child: ColoredBox(
            color: palette.input,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        errorWidget: (_, _, _) => Text(
          '이미지를 불러오지 못했습니다.',
          style: TextStyle(color: palette.textMuted),
        ),
      ),
    );
  }
}

List<_DiscordMediaLink> _discordMediaLinks(
  String content,
  Map<String, String> mediaProxyUrls,
) {
  final matches = RegExp(
    r'https://(?:cdn\.discordapp\.com|media\.discordapp\.net)/[^\s<>()]+',
    caseSensitive: false,
  ).allMatches(content);
  return List.unmodifiable([
    for (final match in matches)
      if (_discordImageUri(match.group(0)) case final uri?)
        _DiscordMediaLink(
          start: match.start,
          end: match.end,
          uri: uri,
          mediaUri: _discordImageUri(mediaProxyUrls[uri.path]) ?? uri,
          fileName: _mediaFileName(uri),
        ),
  ]);
}

Uri? _discordImageUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https') {
    return null;
  }
  const hosts = {'cdn.discordapp.com', 'media.discordapp.net'};
  const roots = {'attachments', 'ephemeral-attachments'};
  const extensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'};
  final segments = uri.pathSegments;
  final extension = segments.isEmpty
      ? ''
      : segments.last.split('.').last.toLowerCase();
  return hosts.contains(uri.host.toLowerCase()) &&
          segments.isNotEmpty &&
          roots.contains(segments.first) &&
          extensions.contains(extension)
      ? uri
      : null;
}

String _mediaFileName(Uri uri) {
  final encoded = uri.pathSegments.isEmpty ? '이미지' : uri.pathSegments.last;
  final decoded = Uri.decodeComponent(encoded);
  return decoded.replaceAll(RegExp(r'[\[\]]'), '');
}

String _markdownWithMediaFileNames(
  String content,
  List<_DiscordMediaLink> links,
) {
  if (links.isEmpty) {
    return content;
  }
  final output = StringBuffer();
  var cursor = 0;
  for (final link in links) {
    output
      ..write(content.substring(cursor, link.start))
      ..write('[${link.fileName}](${link.uri})');
    cursor = link.end;
  }
  output.write(content.substring(cursor));
  return output.toString();
}

class DiscordPollCard extends StatefulWidget {
  const DiscordPollCard({required this.poll, this.onSelectAnswer, super.key});

  final DiscordPoll poll;
  final Future<void> Function(int answerId)? onSelectAnswer;

  @override
  State<DiscordPollCard> createState() => _DiscordPollCardState();
}

class _DiscordPollCardState extends State<DiscordPollCard> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _selectAnswer(int answerId) async {
    final callback = widget.onSelectAnswer;
    if (callback == null || _submitting || widget.poll.finalized) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await callback(answerId);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _pollVoteError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final palette = context.discordPalette;
    final maxVotes = poll.answers.fold<int>(
      1,
      (maximum, answer) =>
          answer.voteCount > maximum ? answer.voteCount : maximum,
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.sidebar,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            poll.question,
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final answer in poll.answers) ...[
            _PollAnswerRow(
              answer: answer,
              maxVotes: maxVotes,
              onPressed:
                  widget.onSelectAnswer == null || poll.finalized || _submitting
                  ? null
                  : () => _selectAnswer(answer.id),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  _pollStatus(poll),
                  style: TextStyle(color: palette.textFaint, fontSize: 12),
                ),
              ),
              if (_submitting)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_errorMessage case final error?) ...[
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: palette.danger, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _PollAnswerRow extends StatelessWidget {
  const _PollAnswerRow({
    required this.answer,
    required this.maxVotes,
    required this.onPressed,
  });

  final DiscordPollAnswer answer;
  final int maxVotes;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    return LayoutBuilder(
      builder: (context, constraints) => InkWell(
        key: ValueKey('poll-answer-${answer.id}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(
              color: answer.meVoted ? palette.brand : palette.divider,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SizedBox(
                width: constraints.maxWidth * answer.voteCount / maxVotes,
                child: ColoredBox(color: palette.brand.withValues(alpha: 0.18)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      answer.meVoted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: answer.meVoted ? palette.brand : palette.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        answer.text,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textNormal),
                      ),
                    ),
                    Text(
                      '${answer.voteCount}',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _pollVoteError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  final message = error.toString();
  return message.isEmpty ? '투표 요청에 실패했습니다.' : message;
}

String _pollStatus(DiscordPoll poll) {
  final selection = poll.allowMultiselect ? '복수 선택' : '단일 선택';
  final state = poll.finalized ? '종료됨' : '진행 중';
  return '${poll.totalVotes}표 · $selection · $state';
}

class DiscordMarkdownBody extends StatelessWidget {
  const DiscordMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      inlineSyntaxes: [DiscordSpoilerSyntax()],
      builders: {'discord-spoiler': DiscordSpoilerBuilder()},
      imageBuilder: _buildMarkdownImage,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: palette.textNormal, height: 1.35),
        pPadding: EdgeInsets.zero,
        a: TextStyle(color: palette.link),
        code: TextStyle(
          color: palette.text,
          backgroundColor: palette.window,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: palette.window,
          border: Border.all(color: palette.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.textFaint, width: 3)),
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
          color: _revealed
              ? context.discordPalette.selected
              : context.discordPalette.window,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            _revealed ? widget.text : '스포일러',
            style: widget.style?.copyWith(
              color: context.discordPalette.textNormal,
            ),
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
        ? context.discordPalette.brand
        : Color(0xFF000000 | embed.color!);
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.discordPalette.sidebar,
        border: Border(left: BorderSide(color: accent, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embed.authorName case final author?)
            Text(
              author,
              style: TextStyle(
                color: context.discordPalette.textNormal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (embed.title case final title?) ...[
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: context.discordPalette.link,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (embed.description case final description?) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: context.discordPalette.textNormal),
            ),
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
                          style: TextStyle(
                            color: context.discordPalette.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          field.value,
                          style: TextStyle(
                            color: context.discordPalette.textNormal,
                          ),
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
              style: TextStyle(
                color: context.discordPalette.textFaint,
                fontSize: 11,
              ),
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
        color: context.discordPalette.sidebar,
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
              errorBuilder: (context, _, _) => SizedBox(
                width: 156,
                height: 64,
                child: Center(
                  child: Icon(
                    Icons.broken_image,
                    color: context.discordPalette.textFaint,
                  ),
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
              Icon(Icons.emoji_emotions, color: context.discordPalette.warning),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sticker.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.discordPalette.textNormal),
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
        child: Center(
          child: Icon(Icons.image, color: context.discordPalette.textFaint),
        ),
      ),
      errorWidget: (context, _, _) => SizedBox(
        width: width,
        height: 64,
        child: Center(
          child: Icon(
            Icons.broken_image,
            color: context.discordPalette.textFaint,
          ),
        ),
      ),
    );
  }
}
