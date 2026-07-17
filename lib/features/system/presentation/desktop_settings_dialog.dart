import 'dart:async';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/app/providers.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_system_controller.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSettingsDialog extends ConsumerStatefulWidget {
  const DesktopSettingsDialog({super.key});

  @override
  ConsumerState<DesktopSettingsDialog> createState() =>
      _DesktopSettingsDialogState();
}

class _DesktopSettingsDialogState extends ConsumerState<DesktopSettingsDialog> {
  bool _busy = false;
  String? _operationError;

  @override
  Widget build(BuildContext context) {
    final systemState = ref
        .watch(desktopSystemStateProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const DesktopSystemState(
            isInitialized: true,
            errorMessage: '설정을 불러오지 못했습니다.',
          ),
          loading: DesktopSystemState.new,
        );
    final accountState = ref
        .watch(accountSessionStateProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const DiscordAccountSessionState(
            errorMessage: '저장 계정을 불러오지 못했습니다.',
          ),
          loading: DiscordAccountSessionState.new,
        );
    final audioDevices = ref
        .watch(audioDeviceCatalogProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const DiscordAudioDeviceCatalog(),
          loading: DiscordAudioDeviceCatalog.new,
        );
    return AlertDialog(
      title: const Text('사용자 설정'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AppearanceSection(
                settings: systemState.settings,
                enabled: !_busy,
                onChanged: _updateSettings,
              ),
              const Divider(height: 32),
              _VoiceSection(
                settings: systemState.settings,
                devices: audioDevices,
                enabled: !_busy,
                onChanged: _updateSettings,
              ),
              const Divider(height: 32),
              _SystemSection(
                settings: systemState.settings,
                enabled: !_busy,
                onChanged: _updateSettings,
              ),
              const Divider(height: 32),
              _AccountSection(
                state: accountState,
                enabled: !_busy,
                onSwitch: _switchAccount,
                onRemove: _confirmRemoveAccount,
              ),
              if (_operationError ?? systemState.errorMessage case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Future<void> _updateSettings(DesktopSettings settings) {
    return _runOperation(
      () => ref.read(desktopSystemControllerProvider).updateSettings(settings),
    );
  }

  Future<void> _switchAccount(String accountId) async {
    final succeeded = await _runOperation(
      () => ref.read(appControllerProvider).switchAccount(accountId),
    );
    if (succeeded && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRemoveAccount(SavedDiscordAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장 계정 삭제'),
        content: Text('${account.label} 계정의 저장 토큰을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runOperation(
        () => ref.read(appControllerProvider).removeSavedAccount(account.id),
      );
    }
  }

  Future<bool> _runOperation(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _operationError = null;
    });
    try {
      await operation();
      return true;
    } on Object {
      if (mounted) {
        setState(() {
          _operationError = '요청을 완료하지 못했습니다. 연결과 설정을 확인하세요.';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _VoiceSection extends StatelessWidget {
  const _VoiceSection({
    required this.settings,
    required this.devices,
    required this.enabled,
    required this.onChanged,
  });

  final DesktopSettings settings;
  final DiscordAudioDeviceCatalog devices;
  final bool enabled;
  final ValueChanged<DesktopSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('음성 및 비디오', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _DeviceDropdown(
          label: '입력 장치',
          selectedId: settings.inputDeviceId,
          devices: devices.inputDevices,
          enabled: enabled,
          onChanged: (deviceId) {
            onChanged(settings.copyWith(inputDeviceId: deviceId));
          },
        ),
        const SizedBox(height: 12),
        _DeviceDropdown(
          label: '출력 장치',
          selectedId: settings.outputDeviceId,
          devices: devices.outputDevices,
          enabled: enabled,
          onChanged: (deviceId) {
            onChanged(settings.copyWith(outputDeviceId: deviceId));
          },
        ),
        const SizedBox(height: 8),
        const Text('장치 변경은 다음 음성 연결부터 적용됩니다.'),
      ],
    );
  }
}

class _DeviceDropdown extends StatelessWidget {
  const _DeviceDropdown({
    required this.label,
    required this.selectedId,
    required this.devices,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String selectedId;
  final List<DiscordAudioDevice> devices;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelected = devices.any((device) => device.id == selectedId);
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('시스템 기본값')),
        if (selectedId.isNotEmpty && !hasSelected)
          DropdownMenuItem(
            value: selectedId,
            child: Text('저장된 장치 ($selectedId)'),
          ),
        for (final device in devices)
          DropdownMenuItem(
            value: device.id,
            child: Text(
              device.isDefault ? '${device.label} · 기본값' : device.label,
            ),
          ),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) {
                onChanged(value);
              }
            }
          : null,
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  static const _accentColors = [
    0xFF5865F2,
    0xFF00A8FC,
    0xFF23A55A,
    0xFFF0B232,
    0xFFEB459E,
  ];

  final DesktopSettings settings;
  final bool enabled;
  final ValueChanged<DesktopSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('외관', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Text('테마'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in _themeChoices)
              ChoiceChip(
                key: ValueKey('theme-${choice.$1.name}'),
                label: Text(choice.$2),
                selected: settings.themeMode == choice.$1,
                onSelected: enabled
                    ? (_) => onChanged(settings.copyWith(themeMode: choice.$1))
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('UI 밀도'),
        const SizedBox(height: 8),
        SegmentedButton<DesktopDisplayDensity>(
          segments: const [
            ButtonSegment(
              value: DesktopDisplayDensity.compact,
              label: Text('Compact'),
            ),
            ButtonSegment(
              value: DesktopDisplayDensity.defaultMode,
              label: Text('Default'),
            ),
            ButtonSegment(
              value: DesktopDisplayDensity.spacious,
              label: Text('Spacious'),
            ),
          ],
          selected: {settings.displayDensity},
          onSelectionChanged: enabled
              ? (selection) => onChanged(
                  settings.copyWith(displayDensity: selection.single),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text('채널 목록 너비 ${settings.channelSidebarWidth.round()}px'),
        Slider(
          key: const ValueKey('channel-sidebar-width'),
          min: DesktopSettings.minChannelSidebarWidth,
          max: DesktopSettings.maxChannelSidebarWidth,
          divisions: 14,
          value: normalizeChannelSidebarWidth(settings.channelSidebarWidth),
          label: '${settings.channelSidebarWidth.round()}px',
          onChanged: enabled
              ? (value) =>
                    onChanged(settings.copyWith(channelSidebarWidth: value))
              : null,
        ),
        const SizedBox(height: 8),
        const Text('강조 색상'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final colorValue in _accentColors)
              ChoiceChip(
                label: SizedBox.square(
                  dimension: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                selected: settings.accentColorValue == colorValue,
                onSelected: enabled
                    ? (_) => onChanged(
                        settings.copyWith(accentColorValue: colorValue),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  static const _themeChoices = <(DesktopThemeMode, String)>[
    (DesktopThemeMode.system, '시스템'),
    (DesktopThemeMode.light, 'Light'),
    (DesktopThemeMode.ash, 'Ash'),
    (DesktopThemeMode.dark, 'Dark'),
    (DesktopThemeMode.onyx, 'Onyx'),
  ];
}

class _SystemSection extends StatelessWidget {
  const _SystemSection({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  final DesktopSettings settings;
  final bool enabled;
  final ValueChanged<DesktopSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Windows', style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('닫을 때 트레이로 최소화'),
          value: settings.minimizeToTray,
          onChanged: enabled
              ? (value) => onChanged(settings.copyWith(minimizeToTray: value))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('새 메시지 알림 및 소리'),
          value: settings.notificationsEnabled,
          onChanged: enabled
              ? (value) =>
                    onChanged(settings.copyWith(notificationsEnabled: value))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('전역 단축키 Ctrl+Shift+D'),
          subtitle: const Text('어디서든 Discord Native 창을 엽니다.'),
          value: settings.globalShortcutEnabled,
          onChanged: enabled
              ? (value) =>
                    onChanged(settings.copyWith(globalShortcutEnabled: value))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('자동 업데이트'),
          subtitle: const Text('HTTPS 업데이트 피드가 구성된 빌드에서 동작합니다.'),
          value: settings.autoUpdateEnabled,
          onChanged: enabled
              ? (value) =>
                    onChanged(settings.copyWith(autoUpdateEnabled: value))
              : null,
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.state,
    required this.enabled,
    required this.onSwitch,
    required this.onRemove,
  });

  final DiscordAccountSessionState state;
  final bool enabled;
  final ValueChanged<String> onSwitch;
  final ValueChanged<SavedDiscordAccount> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('저장 계정', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (state.accounts.isEmpty)
          const Text('READY가 완료된 계정이 여기에 안전하게 저장됩니다.')
        else
          for (final account in state.accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(account.label.characters.first),
              ),
              title: Text(account.label),
              subtitle: Text('@${account.username}'),
              selected: account.id == state.selectedAccountId,
              onTap: enabled && account.id != state.selectedAccountId
                  ? () => onSwitch(account.id)
                  : null,
              trailing: IconButton(
                tooltip: '저장 계정 삭제',
                onPressed: enabled ? () => onRemove(account) : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
      ],
    );
  }
}
