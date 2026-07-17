final class GatewayBackoffPolicy {
  const GatewayBackoffPolicy({this.maximumDelay = const Duration(seconds: 30)});

  final Duration maximumDelay;

  Duration delayForAttempt(int attempt) {
    final exponent = attempt.clamp(0, 30);
    final seconds = 1 << exponent;
    final delay = Duration(seconds: seconds);
    return delay > maximumDelay ? maximumDelay : delay;
  }
}
