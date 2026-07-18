# Discord Native

[![Windows CI](https://github.com/turin-dev/discord-native/actions/workflows/windows.yml/badge.svg)](https://github.com/turin-dev/discord-native/actions/workflows/windows.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter)](https://flutter.dev/)

Flutter로 만든 비공식 Windows Discord 클라이언트입니다. 네이티브 데스크톱 통합과 음성·영상 경로를 포함한 현재 구현 소스 전체를 공개합니다. 현대 READY의 `users`·`recipient_ids`와 desktop guild `properties`를 복원하는 Discord형 shell, DM header 메시지 검색, guild·DM 공통 고정 메시지 panel, Discord CDN 미디어 링크의 인라인 표시, Windows 전역 Push-to-Talk, 네 가지 명암 테마, 세 단계 표시 밀도, 가변 길드 채널 사이드바, 채널 고정과 탐색 기록을 제공합니다.

> [!CAUTION]
> 일반 사용자 계정을 자동화하거나 사용자 토큰으로 비공식 클라이언트에 접속하는 행위는 [Discord 서비스 약관](https://discord.com/terms)과 [self-bot 정책](https://support.discord.com/hc/en-us/articles/115002192352-Automated-User-Accounts-Self-Bots)을 위반해 계정이 정지될 수 있습니다. 본 프로젝트는 Discord와 제휴하거나 승인받지 않았으며, 사용에 따른 책임은 사용자에게 있습니다. 토큰을 이슈·로그·스크린샷에 올리지 마세요.

## 구현 기능

| 영역 | 포함 기능 |
| --- | --- |
| 계정 | secure storage 기반 토큰 보관, 다중 계정 추가·전환·삭제, 로그아웃 |
| 메시징 | 길드·DM·그룹 DM, reply, 첨부·CDN media unfurl, reaction, 편집·삭제, pin·고정 메시지 panel, pagination, typing, guild·DM header 검색, poll 생성·참여, 양방향 read state, thread·forum |
| 커뮤니티 | 친구·요청·차단, member·presence, role·permission overwrite, channel·invite·scheduled event 관리, emoji·sticker |
| 음성 | Voice Gateway v8, UDP/RTP, Opus, AEAD, DAVE E2EE, 입력·출력 장치 선택, mute·deafen, VAD·Windows 전역 F1–F12 PTT, 사용자별 음량 |
| 영상 | WebRTC signaling, H264 카메라, Go Live 화면 공유·시청, 사용자별 video tile |
| Windows | tray, native notification, global shortcut, title bar Inbox, system/light/ash/dark/onyx theme, 표시 밀도, 320px DM shell, 가변 guild sidebar, channel pin·back/forward history, SQLite offline cache |
| 배포 | release benchmark, portable artifact, Inno Setup installer, SHA-256, WinSparkle DSA 서명 업데이트 |

Discord 공개 API가 제공하지 않는 기능과 실환경 검증이 남은 항목이 있으므로 공식 클라이언트와의 절대적인 feature parity는 보장하지 않습니다. DM 메시지 검색, 사용자 poll vote, 양방향 read state와 READY private-channel payload 일부는 공개 개발자 API가 아닌 공식 클라이언트 동작을 바탕으로 하며, read ACK가 거부되면 로컬 unread를 유지하고 경고를 표시합니다. 자세한 제한은 [Open Questions](Open%20Questions.md)를 확인하세요.

## 요구 사항

- Windows 10/11 x64
- Flutter 3.41.9 stable과 Dart 3.11 이상
- Visual Studio 2022/2026의 Desktop development with C++ workload
- CMake와 Windows SDK

## 빠른 시작

PowerShell에서:

```powershell
git clone https://github.com/turin-dev/discord-native.git
cd discord-native
.\setup.ps1
flutter run -d windows
```

Git Bash/WSL 호환 진입점은 `./setup.sh`입니다. 이 프로젝트는 `.env`를 읽지 않습니다. [.env.example](.env.example)은 CI 운영값 이름을 설명하는 참조 문서일 뿐이며 실제 비밀값은 GitHub Actions secrets 또는 로컬 보안 저장소에 넣어야 합니다.

## 검증과 빌드

```powershell
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --minimum=80
flutter build windows --release --split-debug-info=build/symbols/windows
.\tool\subset_material_icons.ps1
.\tool\benchmark_windows.ps1 -Enforce
```

기준선은 analyzer 0건, 377개 테스트, line coverage 81.11%, Windows Release build 통과입니다. 현재 소스의 로컬 측정값은 시작 0.283초, working set 218.62MB, idle CPU 5.5%, 설치 디렉터리 59.34MB이며 메모리와 idle CPU가 각각 200MB·0.5% 기준을 넘었습니다. 성능 결과는 머신 상태에 영향을 받으므로 CI 산출물의 같은 JSON 측정값과 함께 판단합니다. Visual Studio file tracker 문제가 발생하면 `.\tool\build_windows.ps1 --debug` wrapper를 사용할 수 있습니다.

Installer와 서명 업데이트 절차는 [Windows Release runbook](07%20Runbooks/Windows%20Release.md)에 있습니다. 실제 tag release 전에는 운영 HTTPS feed와 별도 생성한 WinSparkle DSA key pair를 설정해야 합니다.

## UI 계약

데스크톱 shell은 Discord의 32px title bar, 72px guild rail, 기본 240px guild channel sidebar, 320px DM sidebar, 48px channel header와 240px member panel 구조를 따릅니다. guild channel sidebar는 220–360px 범위에서 조절되며 compact/default/spacious 표시 밀도를 지원합니다. 1:1 DM은 member panel 없이 대화 폭을 사용하고 group DM만 participant panel을 표시합니다. 세부 원칙과 치수는 [DESIGN.md](DESIGN.md), 기본 dark token은 [design-tokens.json](design-tokens.json), 정적 reference는 [design-preview.html](design-preview.html)에서 확인할 수 있습니다.

## 구조

- `lib/`: Flutter UI, Gateway/REST, 상태·도메인·저장소 구현
- `windows/`: Windows runner와 native DAVE/Opus 통합
- `third_party/`: 고정된 WebRTC/libdatachannel/mbedTLS 소스
- `test/`: 단위·통합 테스트
- `tool/`, `packaging/`: 검증, benchmark, installer, update signing
- [Home.md](Home.md): 프로젝트 위키 진입점

## 기여와 보안

[CONTRIBUTING.md](CONTRIBUTING.md)의 테스트·리뷰 규칙을 따라 주세요. 취약점이나 토큰 노출은 공개 이슈 대신 [SECURITY.md](SECURITY.md)의 비공개 신고 절차를 이용하세요.

## 라이선스와 상표

프로젝트 자체 코드는 [MIT License](LICENSE)로 배포합니다. vendored 코드와 번들 바이너리는 각자의 라이선스를 유지하며 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 정리되어 있습니다. Discord 이름과 로고는 Discord Inc.의 상표이며 이 저장소의 MIT 허가는 해당 상표 사용권을 부여하지 않습니다.
