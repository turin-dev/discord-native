---
type: hub
status: active
tags: [discord-native, wiki]
source_paths: [plan.md, lib/, windows/]
reviewed_at: 2026-07-17
confidence: high
aliases: [Discord Native Wiki]
---

# Discord Native Wiki

Discord Native의 현재 구현과 운영 기준을 연결하는 진입점이다.

- [[02 Architecture/_Index|Architecture]]
- [[03 Modules/_Index|Modules]]
- [[04 Flows/_Index|Flows]]
- [[07 Runbooks/_Index|Runbooks]]
- [[Glossary]]
- [[Open Questions]]
- [[Change Log]]

검증된 구현 범위는 인증·다중 계정, Gateway/REST, 길드·DM·친구·메시징·검색·관리 기능, Voice v8/UDP/RTP/Opus/AEAD/DAVE, WebRTC 카메라·Go Live, Windows 트레이·알림·전역 단축키·테마·오프라인 캐시·서명 업데이트이다. Windows Release 빌드는 320개 테스트와 80.48% line coverage를 통과했고, 시작 0.200초·메모리 99.60MB·유휴 CPU 0%·설치 디렉터리 59.05MB를 기록했다. 패키징과 운영 절차는 [[Windows Release]], 프로토콜과 플랫폼 제약은 [[Open Questions]]에서 관리한다.
