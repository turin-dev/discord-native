import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class DiscordTitleBar extends StatelessWidget {
  const DiscordTitleBar({
    this.onSearch,
    this.onBack,
    this.onForward,
    this.onOpenInbox,
    this.onOpenHelp,
    super.key,
  });

  final ValueChanged<String>? onSearch;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('discord-title-bar'),
      height: DiscordLayout.titleBarHeight,
      child: ColoredBox(
        color: context.discordPalette.window,
        child: Row(
          children: [
            SizedBox(
              width: 152,
              child: _NavigationControls(onBack: onBack, onForward: onForward),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 260,
                  height: 24,
                  child: _GlobalSearch(onSearch),
                ),
              ),
            ),
            SizedBox(
              width: 104,
              child: _TitleActions(
                onOpenInbox: onOpenInbox,
                onOpenHelp: onOpenHelp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationControls extends StatelessWidget {
  const _NavigationControls({required this.onBack, required this.onForward});

  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final palette = context.discordPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        Icon(Icons.discord, size: 17, color: palette.textMuted),
        const SizedBox(width: 8),
        _TitleIconButton(
          tooltip: '뒤로',
          icon: Icons.arrow_back_ios_new,
          onPressed: onBack,
        ),
        _TitleIconButton(
          tooltip: '앞으로',
          icon: Icons.arrow_forward_ios,
          onPressed: onForward,
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
    final palette = context.discordPalette;
    return TextField(
      key: const ValueKey('discord-global-search'),
      onSubmitted: onSearch,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(color: palette.textNormal, fontSize: 12),
      decoration: InputDecoration(
        hintText: '대화 찾기',
        hintStyle: TextStyle(color: palette.textFaint, fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 14),
        prefixIconConstraints: const BoxConstraints(minWidth: 30),
        filled: true,
        fillColor: palette.input,
        border: const OutlineInputBorder(
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
  const _TitleActions({required this.onOpenInbox, required this.onOpenHelp});

  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TitleIconButton(
          tooltip: '받은 편지함',
          icon: Icons.inbox_outlined,
          onPressed: onOpenInbox,
        ),
        _TitleIconButton(
          tooltip: '도움말',
          icon: Icons.help_outline,
          onPressed: onOpenHelp,
        ),
      ],
    );
  }
}

class _TitleIconButton extends StatelessWidget {
  const _TitleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 16, color: context.discordPalette.textMuted),
    );
  }
}
