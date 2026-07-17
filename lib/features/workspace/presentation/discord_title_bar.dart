import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class DiscordTitleBar extends StatelessWidget {
  const DiscordTitleBar({this.onSearch, super.key});

  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('discord-title-bar'),
      height: DiscordLayout.titleBarHeight,
      child: ColoredBox(
        color: DiscordColors.window,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(left: 12, child: _AppMark()),
            SizedBox(width: 260, height: 24, child: _GlobalSearch(onSearch)),
            const Positioned(right: 12, child: _TitleActions()),
          ],
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.discord, size: 17, color: DiscordColors.textMuted),
        SizedBox(width: 7),
        Text(
          'Discord Native',
          style: TextStyle(color: DiscordColors.textFaint, fontSize: 12),
        ),
      ],
    );
  }
}

class _GlobalSearch extends StatelessWidget {
  const _GlobalSearch(this.onSearch);

  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('discord-global-search'),
      onSubmitted: onSearch,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(color: DiscordColors.textNormal, fontSize: 12),
      decoration: const InputDecoration(
        hintText: '대화 찾기',
        hintStyle: TextStyle(color: DiscordColors.textFaint, fontSize: 12),
        prefixIcon: Icon(Icons.search, size: 14),
        prefixIconConstraints: BoxConstraints(minWidth: 30),
        filled: true,
        fillColor: Color(0xFF2A2B30),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
    );
  }
}

class _TitleActions extends StatelessWidget {
  const _TitleActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 17, color: DiscordColors.textMuted),
        SizedBox(width: 12),
        Icon(Icons.help_outline, size: 17, color: DiscordColors.textMuted),
      ],
    );
  }
}
