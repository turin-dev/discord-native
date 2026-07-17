import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class WorkspaceUserActionButton extends StatelessWidget {
  const WorkspaceUserActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: context.discordPalette.textMuted),
    );
  }
}

enum _WorkspaceUserMenuAction { settings, logout }

class WorkspaceUserMenu extends StatelessWidget {
  const WorkspaceUserMenu({
    required this.onOpenSettings,
    required this.onLogout,
    super.key,
  });

  final VoidCallback? onOpenSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_WorkspaceUserMenuAction>(
      tooltip: '사용자 메뉴',
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.settings,
        size: 18,
        color: context.discordPalette.textMuted,
      ),
      onSelected: (action) => _onSelected(action),
      itemBuilder: (_) => [
        if (onOpenSettings != null)
          const PopupMenuItem(
            value: _WorkspaceUserMenuAction.settings,
            child: Text('사용자 설정'),
          ),
        const PopupMenuItem(
          value: _WorkspaceUserMenuAction.logout,
          child: Text('로그아웃'),
        ),
      ],
    );
  }

  void _onSelected(_WorkspaceUserMenuAction action) {
    switch (action) {
      case _WorkspaceUserMenuAction.settings:
        onOpenSettings?.call();
      case _WorkspaceUserMenuAction.logout:
        onLogout();
    }
  }
}
