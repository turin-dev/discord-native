import 'package:discord_native/features/system/domain/desktop_push_to_talk.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter/material.dart';

class DesktopVoiceSettingsSection extends StatelessWidget {
  const DesktopVoiceSettingsSection({
    required this.settings,
    required this.devices,
    required this.enabled,
    required this.onChanged,
    super.key,
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
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('전역 Push-to-Talk'),
          subtitle: const Text('다른 Windows 앱이나 게임을 사용하는 동안에도 동작합니다.'),
          value: settings.globalPushToTalkEnabled,
          onChanged: enabled
              ? (value) =>
                    onChanged(settings.copyWith(globalPushToTalkEnabled: value))
              : null,
        ),
        _PushToTalkControls(
          settings: settings,
          enabled: enabled && settings.globalPushToTalkEnabled,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PushToTalkControls extends StatelessWidget {
  const _PushToTalkControls({
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DesktopPushToTalkKey>(
          initialValue: settings.pushToTalkKey,
          decoration: const InputDecoration(labelText: 'PTT 단축키'),
          items: [
            for (final key in DesktopPushToTalkKey.values)
              DropdownMenuItem(value: key, child: Text(key.label)),
          ],
          onChanged: enabled
              ? (key) {
                  if (key != null) {
                    onChanged(settings.copyWith(pushToTalkKey: key));
                  }
                }
              : null,
        ),
        const SizedBox(height: 12),
        Text('릴리스 지연 ${settings.pushToTalkReleaseDelayMs}ms'),
        Slider(
          key: const ValueKey('push-to-talk-release-delay'),
          min: minPushToTalkReleaseDelayMs.toDouble(),
          max: maxPushToTalkReleaseDelayMs.toDouble(),
          divisions: 40,
          value: normalizePushToTalkReleaseDelay(
            settings.pushToTalkReleaseDelayMs,
          ).toDouble(),
          label: '${settings.pushToTalkReleaseDelayMs}ms',
          onChanged: enabled
              ? (value) => onChanged(
                  settings.copyWith(pushToTalkReleaseDelayMs: value.round()),
                )
              : null,
        ),
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
