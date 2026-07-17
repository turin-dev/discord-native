final class DiscordAudioDevice {
  const DiscordAudioDevice({
    required this.id,
    required this.label,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final bool isDefault;

  @override
  bool operator ==(Object other) {
    return other is DiscordAudioDevice &&
        other.id == id &&
        other.label == label &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(id, label, isDefault);
}

final class DiscordAudioDeviceCatalog {
  const DiscordAudioDeviceCatalog({
    this.inputDevices = const [],
    this.outputDevices = const [],
  });

  final List<DiscordAudioDevice> inputDevices;
  final List<DiscordAudioDevice> outputDevices;
}
