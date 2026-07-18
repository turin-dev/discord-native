import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class DiscordGuildIcon extends StatelessWidget {
  const DiscordGuildIcon({
    required this.guild,
    this.selected = false,
    this.size = DiscordLayout.guildIconSize,
    super.key,
  });

  final DiscordGuild guild;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    final radius = BorderRadius.all(
      selected ? DiscordRadius.guild : DiscordRadius.round,
    );
    final imageUrl = _guildIconUrl(guild);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected ? palette.brand : palette.chat,
        borderRadius: radius,
      ),
      child: imageUrl == null
          ? Center(child: _Initials(label: guild.name, fontSize: 14))
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  Center(child: _Initials(label: guild.name, fontSize: 14)),
            ),
    );
  }
}

class DiscordUserAvatar extends StatelessWidget {
  const DiscordUserAvatar({
    required this.user,
    this.radius = 18,
    this.statusColor,
    super.key,
  });

  final DiscordUser? user;
  final double radius;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    final imageUrl = _avatarUrl(user);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _identityColor(user?.id ?? 'pending'),
          foregroundImage: imageUrl == null
              ? null
              : CachedNetworkImageProvider(imageUrl),
          child: imageUrl == null
              ? _Initials(
                  label: user?.displayName ?? user?.username ?? '?',
                  fontSize: radius * 0.72,
                )
              : null,
        ),
        if (statusColor != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: palette.sidebar, width: 2),
              ),
              child: SizedBox.square(dimension: radius * 0.7),
            ),
          ),
      ],
    );
  }
}

class DiscordInitialAvatar extends StatelessWidget {
  const DiscordInitialAvatar({
    required this.id,
    required this.label,
    this.avatarHash,
    this.radius = 20,
    super.key,
  });

  final String id;
  final String label;
  final String? avatarHash;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _avatarUrlFromParts(id, avatarHash);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _identityColor(id),
      foregroundImage: imageUrl == null
          ? null
          : CachedNetworkImageProvider(imageUrl),
      child: imageUrl == null
          ? _Initials(label: label, fontSize: radius * 0.72)
          : null,
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      _initials(label),
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String? _guildIconUrl(DiscordGuild guild) {
  final hash = guild.iconHash;
  if (hash == null) {
    return null;
  }
  final extension = hash.startsWith('a_') ? 'gif' : 'webp';
  return 'https://cdn.discordapp.com/icons/${guild.id}/$hash.$extension?size=128';
}

String? _avatarUrl(DiscordUser? user) {
  if (user == null) {
    return null;
  }
  return _avatarUrlFromParts(user.id, user.avatarHash);
}

String? _avatarUrlFromParts(String id, String? hash) {
  if (hash == null) {
    return null;
  }
  final extension = hash.startsWith('a_') ? 'gif' : 'webp';
  return 'https://cdn.discordapp.com/avatars/$id/$hash.$extension?size=128';
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) {
    return '?';
  }
  return words
      .take(2)
      .map((word) => word.characters.first)
      .join()
      .toUpperCase();
}

Color _identityColor(String id) {
  const colors = [
    Color(0xFF5865F2),
    Color(0xFF3BA55C),
    Color(0xFFEB459E),
    Color(0xFFFAA61A),
    Color(0xFF57F287),
  ];
  final hash = id.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return colors[hash % colors.length];
}
