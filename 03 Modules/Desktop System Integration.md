---
type: module
status: active
tags: [windows, system, accounts, cache, ptt]
source_paths: [lib/features/system/, lib/core/auth/discord_account_repository.dart, lib/core/auth/discord_account_session_controller.dart, lib/features/messages/data/message_cache_repository.dart]
reviewed_at: 2026-07-18
confidence: high
aliases: [Desktop System Integration]
---

# Desktop System Integration

Windows 전용 동작은 `DesktopSystemBridge` 경계 뒤에 둔다. `WindowsDesktopSystemBridge`는 창 닫기 시 트레이 최소화, 트레이 메뉴, `Ctrl+Shift+D` 창 복원 단축키, F1–F12 전역 PTT press/release, 로컬 알림과 자동 업데이트를 담당한다. 비 Windows 환경과 단위 테스트는 `NoopDesktopSystemBridge`를 사용한다.

사용자 설정은 불변 `DesktopSettings`로 관리하고 secure storage에 JSON으로 저장한다. 테마는 system/light/ash/dark/onyx와 강조 색상을 지원하고, compact/default/spacious 표시 밀도, 220–360px channel sidebar 폭, pinned channel ID와 입력·출력 오디오 장치 ID를 함께 보존한다. 알림·트레이·창 복원 단축키·전역 PTT·자동 업데이트는 각각 끌 수 있고, PTT key와 0–2000ms release delay도 저장한다. 업데이트는 `DISCORD_NATIVE_UPDATE_FEED`에 유효한 HTTPS 피드가 주입되고 WinSparkle DSA public key가 runner resource에 포함된 Release build에서만 배포한다. private key는 CI secret과 서명 단계에만 존재한다.

다중 계정 인덱스에는 사용자 ID와 표시명만 저장하고 토큰은 계정별 secure-storage key로 분리한다. READY 완료 시 현재 토큰과 계정 메타데이터를 연결하고, 계정 전환 전 기존 Gateway와 음성 세션을 정리한다. 계정 삭제는 해당 계정 토큰과 메시지 캐시만 제거한다.

메시지 캐시는 별도 SQLite DB `discord_native_message_cache.db`를 사용한다. 기본적으로 계정·채널별 최근 100개 메시지를 보존하며 primary key에 `account_id`를 포함해 계정 간 누출을 막는다. REST 히스토리 조회 실패 시 현재 계정과 채널의 캐시만 오프라인 상태로 표시하고, Gateway MESSAGE_CREATE/UPDATE/DELETE를 증분 반영한다. 토큰은 DB에 저장하지 않는다.

MESSAGE_CREATE 알림은 현재 사용자 메시지와 현재 열린 채널을 제외한다. 알림 클릭과 창 복원 단축키는 숨겨진 창을 복원한다. 전역 PTT는 Windows `GetAsyncKeyState`로 선택한 단일 key의 down 상태만 읽고 키 문자열이나 입력 기록을 저장·로그하지 않는다. 시스템 기능 실패는 설정 상태의 사용자 친화적 오류로 노출한다.

관련 문서: [[Native Client Architecture]], [[Gateway and Messaging]], [[Windows Development]], [[Windows Release]]
