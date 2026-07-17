final class DiscordWorkspaceLocation {
  const DiscordWorkspaceLocation(this.guildId, this.channelId);

  final String? guildId;
  final String? channelId;

  bool get isEmpty => guildId == null && channelId == null;

  @override
  bool operator ==(Object other) {
    return other is DiscordWorkspaceLocation &&
        other.guildId == guildId &&
        other.channelId == channelId;
  }

  @override
  int get hashCode => Object.hash(guildId, channelId);
}

final class DiscordNavigationHistory {
  const DiscordNavigationHistory({this.entries = const [], this.index = -1});

  final List<DiscordWorkspaceLocation> entries;
  final int index;

  DiscordWorkspaceLocation? get current {
    return index >= 0 && index < entries.length ? entries[index] : null;
  }

  bool get canGoBack => index > 0;
  bool get canGoForward => index >= 0 && index < entries.length - 1;

  DiscordNavigationHistory visit(DiscordWorkspaceLocation location) {
    if (location.isEmpty || current == location) {
      return this;
    }
    final retained = index < 0
        ? const <DiscordWorkspaceLocation>[]
        : entries.take(index + 1);
    final updated = List<DiscordWorkspaceLocation>.unmodifiable([
      ...retained,
      location,
    ]);
    return DiscordNavigationHistory(
      entries: updated,
      index: updated.length - 1,
    );
  }

  DiscordNavigationHistory back() {
    return canGoBack
        ? DiscordNavigationHistory(entries: entries, index: index - 1)
        : this;
  }

  DiscordNavigationHistory forward() {
    return canGoForward
        ? DiscordNavigationHistory(entries: entries, index: index + 1)
        : this;
  }
}
