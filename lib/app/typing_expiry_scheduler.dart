import 'dart:async';

abstract interface class TypingExpiryTask {
  void cancel();
}

abstract interface class TypingExpiryScheduler {
  TypingExpiryTask schedule(Duration duration, void Function() callback);
}

final class TimerTypingExpiryScheduler implements TypingExpiryScheduler {
  const TimerTypingExpiryScheduler();

  @override
  TypingExpiryTask schedule(Duration duration, void Function() callback) {
    return _TimerTypingExpiryTask(Timer(duration, callback));
  }
}

final class _TimerTypingExpiryTask implements TypingExpiryTask {
  const _TimerTypingExpiryTask(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
