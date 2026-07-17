---
type: runbook
status: active
tags: [windows, flutter, build]
source_paths: [windows/CMakeLists.txt, windows/libdave/, tool/build_windows.ps1, lib/features/workspace/data/read_state_repository.dart, lib/features/system/data/windows_desktop_system_bridge.dart, lib/features/workspace/presentation/attachment_video_player.dart]
reviewed_at: 2026-07-17
confidence: high
aliases: [Windows Development]
---

# Windows Development

기본 검증:

```powershell
flutter pub get
flutter analyze
flutter test --coverage
flutter build windows --debug
```

Visual Studio 2026 환경에서는 MSBuild file tracker가 `cl.exe`를 고아 프로세스로 남길 수 있다. `windows/CMakeLists.txt`가 `TrackFileAccess=false`를 CMake `try_compile`까지 전파한다. 문제가 재발하면 다음을 사용한다.

```powershell
.\tool\build_windows.ps1 --debug
```

검증된 산출물은 `build/windows/x64/runner/Debug/discord_native.exe`다.

트레이·창 제어·전역 단축키·Windows 알림·자동 업데이트는 각각 `tray_manager`, `window_manager`, `hotkey_manager`, `local_notifier`, `auto_updater` 플러그인을 사용한다. `windows/flutter/generated_plugin_registrant.cc`와 `generated_plugins.cmake`는 Flutter가 생성하므로 직접 편집하지 않는다.

자동 업데이트를 사용할 release build에는 HTTPS appcast URL을 주입한다. 피드가 없거나 HTTPS가 아니면 업데이트 검사를 등록하지 않는다.

```powershell
flutter build windows --release --dart-define=DISCORD_NATIVE_UPDATE_FEED=https://updates.example.com/appcast.xml
```

음성을 포함한 runner에는 `libdave.dll`, `opus.dll`과 각 라이선스 bundle이 실행 파일 옆에 있어야 한다. `opus.dll`은 `flutter_soloud` playback과 Discord Opus FFI가 공유하며 Release에서는 사용하지 않는 FLAC/Vorbis/Ogg decoder를 배포하지 않는다. DLL 누락은 analyzer나 unit test에서 드러나지 않으므로 Windows build 뒤 산출물 디렉터리를 확인한다.

첨부 영상은 Windows Media Foundation 기반 `video_player_win`을 사용한다. HTTPS URL만 platform backend로 전달하며 재생 실패는 메시지 surface 안에서 사용자 친화적 상태로 표시한다.

로컬 읽음 상태 DB는 Windows application support directory의 `discord_native.db`, 메시지 캐시는 `discord_native_message_cache.db`에 생성된다. 메시지 캐시는 계정별 scope로 분리되고 저장 계정을 삭제할 때 해당 계정 데이터만 비운다. SQLite native asset이 추가됐으므로 Windows build 검증을 생략하지 않는다.

Release 최적화·성능 측정·installer·서명 절차는 [[Windows Release]]를 따른다.

관련 문서: [[Native Client Architecture]], [[Gateway and Messaging]], [[Voice]], [[Desktop System Integration]], [[Authentication to Messaging]], [[Windows Release]]
