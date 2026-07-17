# Repository Guide

## 작업 원칙

- 사용자와 문서는 한국어를 기본으로 하되 코드 식별자는 원문을 유지한다.
- 변경 전에 `Home.md`에서 관련 architecture/module/flow/runbook을 먼저 따라간다.
- 문서와 코드가 다르면 코드를 확인하고 같은 변경에서 wiki와 `Change Log.md`를 동기화한다.
- 기능 변경은 실패하는 테스트부터 추가하는 RED → GREEN → REFACTOR 순서를 따른다.
- 기존 객체를 직접 수정하지 않고 새 객체를 만든다.
- `any`, production `console.log`, silent error handling, hard-coded secrets를 사용하지 않는다.
- commit은 Conventional Commits의 `<type>: <description>` 형식을 사용한다.

## Windows 명령

```powershell
.\setup.ps1
flutter run -d windows
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --minimum=80
flutter build windows --release --split-debug-info=build/symbols/windows
.\tool\subset_material_icons.ps1
.\tool\benchmark_windows.ps1 -Enforce
```

Visual Studio file tracker 문제가 재현되면 `.\tool\build_windows.ps1 --debug`를 사용한다. Installer와 update signing은 `07 Runbooks/Windows Release.md`를 따른다.

## 아키텍처와 주요 파일

- `lib/core/`: config, network, error, theme 등 공통 기반
- `lib/features/`: auth, workspace, voice, video, system 기능과 presentation 상태
- `windows/`: Windows runner, DAVE/Opus native runtime 연결
- `third_party/`: 고정된 WebRTC/libdatachannel/mbedTLS source와 원 라이선스
- `test/`: unit/integration/widget 검증
- `.github/workflows/windows.yml`: analyze, test, coverage, release artifact CI
- `tool/`, `packaging/`: coverage, benchmark, installer, signed appcast 도구
- `Home.md`, `DESIGN.md`, `Open Questions.md`: wiki 진입점, UI 계약, 외부 제약

## 보안과 공개 저장소

- Discord token, session 정보, webhook, 실제 update feed, DSA key, 개인 경로·로그를 commit하지 않는다.
- 앱은 `.env`를 읽지 않는다. `.env.example`은 CI secret 이름을 설명하는 reference-only 파일이다.
- 실제 token은 OS secure storage, release secret은 GitHub Actions secrets 또는 별도 보안 저장소에 둔다.
- `third_party/mbedtls/framework/data_files/` 제거와 `.gitleaks.toml`의 검토된 최소 allowlist를 유지한다.
- vendored dependency를 바꾸면 버전, upstream, patch, license와 `THIRD_PARTY_NOTICES.md`를 함께 갱신한다.
