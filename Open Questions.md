---
type: open-questions
status: active
tags: [risks, roadmap]
source_paths: [plan.md, lib/]
reviewed_at: 2026-07-17
confidence: high
aliases: [Open Questions]
---

# Open Questions

- 일반 사용자 토큰 클라이언트는 Discord ToS 위반과 계정 정지 위험을 제거할 수 없다.
- 친구 추가·수락·거절·취소·차단·해제·삭제는 구현됐지만 공개 API에 없는 비공식 relationship endpoint이므로 부계정 실기기 검증과 변경 모니터링이 남아 있다.
- Gateway resume 실패 시 jitter와 close code별 재식별 정책을 보강해야 한다.
- 공개 API에는 사용자 클라이언트의 server read ACK가 없어 현재 unread는 로컬 상태이며 공식 클라이언트와 동기화되지 않는다.
- Voice v8, UDP/RTP, Opus, AEAD와 DAVE E2EE 음성 경로는 구현됐지만 실제 Discord 계정 2개를 사용한 장시간 통화, 장치 hot swap, echo cancellation과 noise suppression 검증이 남아 있다.
- 카메라 화상과 Go Live 화면공유 경로는 구현됐지만 실제 Discord SFU와 복수 참가자 환경의 장시간 호환성 검증이 남아 있다.
- PTT는 앱 내 pointer hold를 지원하고 앱 토글용 Windows 전역 단축키는 별도다. 입력·출력 장치 선택과 전역 PTT key binding은 후속 범위다.
- 자동 업데이트 배포에는 운영 HTTPS feed와 실제 WinSparkle DSA key pair를 CI secret으로 주입해야 한다. 저장소에는 key를 포함하지 않는다.
- 공식 클라이언트의 private setting인 서버 폴더·사용자 계정 MFA 자격증명 로그인·서버 read ACK는 안정적인 공개 API가 없어 동일 동작을 보장하지 않는다.

코드·빌드·패키징 마일스톤은 완료됐지만 위 항목은 외부 프로토콜과 운영 환경의 잔여 위험이다. 따라서 공식 클라이언트와의 절대적 feature parity를 보증하지 않는다.

관련 문서: [[Home]], [[Voice]], [[Windows Release]]
