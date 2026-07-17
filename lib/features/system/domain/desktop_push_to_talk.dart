enum DesktopPushToTalkKey { f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12 }

extension DesktopPushToTalkKeyLabel on DesktopPushToTalkKey {
  String get label => name.toUpperCase();
}

const int minPushToTalkReleaseDelayMs = 0;
const int maxPushToTalkReleaseDelayMs = 2000;

int normalizePushToTalkReleaseDelay(int value) {
  return value.clamp(minPushToTalkReleaseDelayMs, maxPushToTalkReleaseDelayMs);
}
