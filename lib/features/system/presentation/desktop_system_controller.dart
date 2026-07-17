import 'dart:async';

import 'package:discord_native/features/system/data/desktop_settings_repository.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/domain/desktop_system_bridge.dart';

final class DesktopSystemState {
  const DesktopSystemState({
    this.settings = const DesktopSettings.defaults(),
    this.isInitialized = false,
    this.errorMessage,
  });

  final DesktopSettings settings;
  final bool isInitialized;
  final String? errorMessage;

  DesktopSystemState copyWith({
    DesktopSettings? settings,
    bool? isInitialized,
    Object? errorMessage = _unset,
  }) {
    return DesktopSystemState(
      settings: settings ?? this.settings,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

final class DesktopSystemController {
  DesktopSystemController(this._repository, this._bridge);

  final DesktopSettingsRepository _repository;
  final DesktopSystemBridge _bridge;
  final StreamController<DesktopSystemState> _states =
      StreamController.broadcast();

  DesktopSystemState _state = const DesktopSystemState();
  bool _disposed = false;

  DesktopSystemState get state => _state;

  Stream<bool> get pushToTalkPressed => _bridge.pushToTalkPressed;

  Stream<DesktopSystemState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  Future<void> initialize() async {
    _ensureActive();
    try {
      final settings = await _repository.load();
      await _bridge.initialize(settings);
      _update(DesktopSystemState(settings: settings, isInitialized: true));
    } on Object {
      _update(
        const DesktopSystemState(
          isInitialized: true,
          errorMessage: '데스크톱 시스템 기능을 초기화하지 못했습니다.',
        ),
      );
    }
  }

  Future<void> updateSettings(DesktopSettings settings) async {
    _ensureActive();
    await _repository.save(settings);
    _update(_state.copyWith(settings: settings, errorMessage: null));
    try {
      await _bridge.apply(settings);
    } on Object {
      _update(_state.copyWith(errorMessage: '데스크톱 설정을 적용하지 못했습니다.'));
    }
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    _ensureActive();
    if (!_state.settings.notificationsEnabled) {
      return;
    }
    try {
      await _bridge.showNotification(
        DesktopNotification(title: title, body: body),
      );
    } on Object {
      _update(_state.copyWith(errorMessage: 'Windows 알림을 표시하지 못했습니다.'));
    }
  }

  Future<void> showWindow() async {
    _ensureActive();
    try {
      await _bridge.showWindow();
    } on Object {
      _update(_state.copyWith(errorMessage: '앱 창을 표시하지 못했습니다.'));
    }
  }

  Future<void> setPushToTalkSessionActive(bool active) async {
    _ensureActive();
    try {
      await _bridge.setPushToTalkSessionActive(active);
    } on Object {
      _update(_state.copyWith(errorMessage: '전역 Push-to-Talk을 적용하지 못했습니다.'));
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _bridge.dispose();
    await _states.close();
  }

  void _update(DesktopSystemState next) {
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('DesktopSystemController가 이미 종료되었습니다.');
    }
  }
}

const Object _unset = Object();
