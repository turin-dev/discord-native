---
type: hub
status: active
tags: [discord-native, wiki]
source_paths: [plan.md, lib/, windows/]
reviewed_at: 2026-07-18
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

검증된 구현 범위는 인증·다중 계정, Gateway/REST, 길드·DM·친구·메시징·투표 생성·참여·검색·고정 메시지·관리 기능과 양방향 read-state 동기화, Voice v8/UDP/RTP/Opus/AEAD/DAVE, WebRTC 카메라·Go Live, Windows 트레이·알림·전역 단축키·전역 PTT·Inbox·테마·표시 밀도·가변 sidebar·채널 고정·탐색 history·오디오 장치 선택·오프라인 캐시·서명 업데이트이다. DM은 현대 READY의 `users`·`recipient_ids`를 결합하고 1:1·group 전용 shell 차이를 보존한다. 현재 전체 검증은 analyzer 0건, 374개 테스트와 80.93% line coverage, Windows Release build를 통과했다. 현재 소스의 로컬 측정은 시작 0.249초·메모리 164.68MB·유휴 CPU 5.25%·설치 디렉터리 59.33MB이며 유휴 CPU만 0.5% 기준을 넘었다. 패키징과 운영 절차는 [[Windows Release]], 프로토콜과 플랫폼 제약은 [[Open Questions]]에서 관리한다.
