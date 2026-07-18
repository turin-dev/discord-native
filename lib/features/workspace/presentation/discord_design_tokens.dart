import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:flutter/material.dart';

@immutable
final class DiscordPalette extends ThemeExtension<DiscordPalette> {
  const DiscordPalette({
    required this.window,
    required this.guildRail,
    required this.sidebar,
    required this.sidebarFooter,
    required this.chat,
    required this.input,
    required this.hover,
    required this.selected,
    required this.divider,
    required this.brand,
    required this.brandHover,
    required this.text,
    required this.textNormal,
    required this.textMuted,
    required this.textFaint,
    required this.link,
    required this.positive,
    required this.warning,
    required this.danger,
  });

  static const light = DiscordPalette(
    window: Color(0xFFE3E5E8),
    guildRail: Color(0xFFE3E5E8),
    sidebar: Color(0xFFF2F3F5),
    sidebarFooter: Color(0xFFEBEDEF),
    chat: Color(0xFFFFFFFF),
    input: Color(0xFFEBEDEF),
    hover: Color(0xFFE3E5E8),
    selected: Color(0xFFD4D7DC),
    divider: Color(0xFFD4D7DC),
    brand: Color(0xFF5865F2),
    brandHover: Color(0xFF4752C4),
    text: Color(0xFF060607),
    textNormal: Color(0xFF313338),
    textMuted: Color(0xFF4E5058),
    textFaint: Color(0xFF5C5E66),
    link: Color(0xFF006CE7),
    positive: Color(0xFF248046),
    warning: Color(0xFFAF6A00),
    danger: Color(0xFFDA373C),
  );

  static const ash = DiscordPalette(
    window: Color(0xFF222327),
    guildRail: Color(0xFF25262B),
    sidebar: Color(0xFF303238),
    sidebarFooter: Color(0xFF292B30),
    chat: Color(0xFF383A40),
    input: Color(0xFF404249),
    hover: Color(0xFF404249),
    selected: Color(0xFF4E5058),
    divider: Color(0xFF25262B),
    brand: Color(0xFF5865F2),
    brandHover: Color(0xFF4752C4),
    text: Color(0xFFF2F3F5),
    textNormal: Color(0xFFDBDEE1),
    textMuted: Color(0xFFB5BAC1),
    textFaint: Color(0xFF949BA4),
    link: Color(0xFF00A8FC),
    positive: Color(0xFF23A55A),
    warning: Color(0xFFF0B232),
    danger: Color(0xFFF23F42),
  );

  static const dark = DiscordPalette(
    window: DiscordColors.window,
    guildRail: DiscordColors.guildRail,
    sidebar: DiscordColors.sidebar,
    sidebarFooter: DiscordColors.sidebarFooter,
    chat: DiscordColors.chat,
    input: DiscordColors.input,
    hover: DiscordColors.hover,
    selected: DiscordColors.selected,
    divider: DiscordColors.divider,
    brand: DiscordColors.brand,
    brandHover: DiscordColors.brandHover,
    text: DiscordColors.text,
    textNormal: DiscordColors.textNormal,
    textMuted: DiscordColors.textMuted,
    textFaint: DiscordColors.textFaint,
    link: DiscordColors.link,
    positive: DiscordColors.positive,
    warning: DiscordColors.warning,
    danger: DiscordColors.danger,
  );

  static const onyx = DiscordPalette(
    window: Color(0xFF0A1E2E),
    guildRail: Color(0xFF0C0C0C),
    sidebar: Color(0xFF061027),
    sidebarFooter: Color(0xFF071521),
    chat: Color(0xFF050E23),
    input: Color(0xFF04052B),
    hover: Color(0xFF151C2D),
    selected: Color(0xFF181F30),
    divider: Color(0xFF071521),
    brand: Color(0xFF5865F2),
    brandHover: Color(0xFF4752C4),
    text: Color(0xFFF2F3F5),
    textNormal: Color(0xFFDBDEE1),
    textMuted: Color(0xFFB5BAC1),
    textFaint: Color(0xFF949BA4),
    link: Color(0xFF00A8FC),
    positive: Color(0xFF23A55A),
    warning: Color(0xFFF0B232),
    danger: Color(0xFFF23F42),
  );

  final Color window;
  final Color guildRail;
  final Color sidebar;
  final Color sidebarFooter;
  final Color chat;
  final Color input;
  final Color hover;
  final Color selected;
  final Color divider;
  final Color brand;
  final Color brandHover;
  final Color text;
  final Color textNormal;
  final Color textMuted;
  final Color textFaint;
  final Color link;
  final Color positive;
  final Color warning;
  final Color danger;

  @override
  DiscordPalette copyWith({
    Color? window,
    Color? guildRail,
    Color? sidebar,
    Color? sidebarFooter,
    Color? chat,
    Color? input,
    Color? hover,
    Color? selected,
    Color? divider,
    Color? brand,
    Color? brandHover,
    Color? text,
    Color? textNormal,
    Color? textMuted,
    Color? textFaint,
    Color? link,
    Color? positive,
    Color? warning,
    Color? danger,
  }) {
    return DiscordPalette(
      window: window ?? this.window,
      guildRail: guildRail ?? this.guildRail,
      sidebar: sidebar ?? this.sidebar,
      sidebarFooter: sidebarFooter ?? this.sidebarFooter,
      chat: chat ?? this.chat,
      input: input ?? this.input,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
      divider: divider ?? this.divider,
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      text: text ?? this.text,
      textNormal: textNormal ?? this.textNormal,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      link: link ?? this.link,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  DiscordPalette lerp(DiscordPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return DiscordPalette(
      window: Color.lerp(window, other.window, t)!,
      guildRail: Color.lerp(guildRail, other.guildRail, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarFooter: Color.lerp(sidebarFooter, other.sidebarFooter, t)!,
      chat: Color.lerp(chat, other.chat, t)!,
      input: Color.lerp(input, other.input, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      text: Color.lerp(text, other.text, t)!,
      textNormal: Color.lerp(textNormal, other.textNormal, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      link: Color.lerp(link, other.link, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

DiscordPalette discordPalette(ThemeData theme) {
  return theme.extension<DiscordPalette>() ?? DiscordPalette.dark;
}

extension DiscordThemeContext on BuildContext {
  DiscordPalette get discordPalette =>
      Theme.of(this).extension<DiscordPalette>() ?? DiscordPalette.dark;
}

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
  static const directMessagesSidebarWidth = 320.0;
  static const channelHeaderHeight = 48.0;
  static const rightPanelWidth = 240.0;
  static const userPanelHeight = 52.0;
  static const guildIconSize = 48.0;
  static const channelTileHeight = 34.0;

  static double guildRailWidthFor(DesktopDisplayDensity density) {
    return switch (density) {
      DesktopDisplayDensity.compact => 64,
      DesktopDisplayDensity.defaultMode => guildRailWidth,
      DesktopDisplayDensity.spacious => 80,
    };
  }

  static double guildIconSizeFor(DesktopDisplayDensity density) {
    return switch (density) {
      DesktopDisplayDensity.compact => 42,
      DesktopDisplayDensity.defaultMode => guildIconSize,
      DesktopDisplayDensity.spacious => 52,
    };
  }

  static double channelTileHeightFor(DesktopDisplayDensity density) {
    return switch (density) {
      DesktopDisplayDensity.compact => 30,
      DesktopDisplayDensity.defaultMode => channelTileHeight,
      DesktopDisplayDensity.spacious => 40,
    };
  }

  static double userPanelHeightFor(DesktopDisplayDensity density) {
    return switch (density) {
      DesktopDisplayDensity.compact => 48,
      DesktopDisplayDensity.defaultMode => userPanelHeight,
      DesktopDisplayDensity.spacious => 60,
    };
  }
}

abstract final class DiscordRadius {
  static const small = Radius.circular(4);
  static const medium = Radius.circular(8);
  static const guild = Radius.circular(16);
  static const round = Radius.circular(24);
}

abstract final class DiscordTextStyles {
  static TextStyle body(BuildContext context) => TextStyle(
    color: context.discordPalette.textNormal,
    fontSize: 14,
    height: 1.3,
  );

  static TextStyle channel(BuildContext context) => TextStyle(
    color: context.discordPalette.textMuted,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static TextStyle label(BuildContext context) => TextStyle(
    color: context.discordPalette.textFaint,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.25,
  );

  static TextStyle heading(BuildContext context) => TextStyle(
    color: context.discordPalette.text,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}
