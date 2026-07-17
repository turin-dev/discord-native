import 'package:flutter/material.dart';

abstract final class DiscordColors {
  static const window = Color(0xFF111214);
  static const guildRail = Color(0xFF1E1F22);
  static const sidebar = Color(0xFF2B2D31);
  static const sidebarFooter = Color(0xFF232428);
  static const chat = Color(0xFF313338);
  static const input = Color(0xFF383A40);
  static const hover = Color(0xFF35373C);
  static const selected = Color(0xFF404249);
  static const divider = Color(0xFF1F2023);
  static const brand = Color(0xFF5865F2);
  static const brandHover = Color(0xFF4752C4);
  static const text = Color(0xFFF2F3F5);
  static const textNormal = Color(0xFFDBDEE1);
  static const textMuted = Color(0xFFB5BAC1);
  static const textFaint = Color(0xFF949BA4);
  static const link = Color(0xFF00A8FC);
  static const positive = Color(0xFF23A55A);
  static const warning = Color(0xFFF0B232);
  static const danger = Color(0xFFF23F42);
}

abstract final class DiscordLayout {
  static const titleBarHeight = 32.0;
  static const guildRailWidth = 72.0;
  static const channelSidebarWidth = 240.0;
  static const channelHeaderHeight = 48.0;
  static const rightPanelWidth = 240.0;
  static const userPanelHeight = 52.0;
  static const guildIconSize = 48.0;
  static const channelTileHeight = 34.0;
}

abstract final class DiscordRadius {
  static const small = Radius.circular(4);
  static const medium = Radius.circular(8);
  static const guild = Radius.circular(16);
  static const round = Radius.circular(24);
}

abstract final class DiscordTextStyles {
  static const body = TextStyle(
    color: DiscordColors.textNormal,
    fontSize: 14,
    height: 1.3,
  );
  static const channel = TextStyle(
    color: DiscordColors.textMuted,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
  static const label = TextStyle(
    color: DiscordColors.textFaint,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.25,
  );
  static const heading = TextStyle(
    color: DiscordColors.text,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}
