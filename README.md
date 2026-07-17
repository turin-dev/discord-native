# Discord Native

Flutter 기반 비공식 Windows Discord 클라이언트입니다. Gateway/REST 메시징, 길드·DM·친구·관리 기능, Voice v8/UDP/Opus/DAVE, WebRTC 카메라·Go Live, Windows 트레이·알림·다중 계정·오프라인 캐시·서명 업데이트를 구현합니다.

## 실행

```powershell
flutter pub get
flutter run -d windows
```

Windows Release 빌드:

```powershell
flutter build windows --release --split-debug-info=build/symbols/windows
.\tool\subset_material_icons.ps1
.\tool\benchmark_windows.ps1 -Enforce
```

현재 검증 기준은 analyzer 0건, 320개 테스트, line coverage 80.48%입니다. Release gate 측정값은 시작 0.200초, working set 99.60MB, 유휴 CPU 0%, 설치 디렉터리 59.05MB입니다.

Visual Studio 2026 file tracker 문제가 재현되면 다음 wrapper를 사용할 수 있습니다.

```powershell
.\tool\build_windows.ps1 --debug
```

## 검증

```powershell
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --minimum=80
```

## 중요 제약

일반 사용자 토큰으로 접속하는 비공식 클라이언트는 Discord ToS를 위반할 수 있으며 계정 정지 위험이 있습니다. Discord 공개 API만으로 공식 클라이언트의 전체 사용자 기능과 음성·화상 기능을 안정적으로 재현할 수 없습니다. 테스트는 부계정과 개인 환경에서만 수행해야 합니다.

프로젝트 구조와 현재 범위는 [[Home]], 배포 절차는 [[Windows Release]]에서 확인할 수 있습니다.
