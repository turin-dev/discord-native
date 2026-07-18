---
type: open-questions
status: active
tags: [risks, roadmap]
source_paths: [plan.md, lib/]
reviewed_at: 2026-07-18
confidence: high
aliases: [Open Questions]
---

# Open Questions

- 일반 사용자 토큰 클라이언트는 Discord ToS 위반과 계정 정지 위험을 제거할 수 없다.
- 친구 추가·수락·거절·취소·차단·해제·삭제는 구현됐지만 공개 API에 없는 비공식 relationship endpoint이므로 부계정 실기기 검증과 변경 모니터링이 남아 있다.
- READY private channel은 현재 최상위 `users`와 `recipient_ids`를 결합하고 예전 embedded `recipients`도 허용한다. 이 payload shape는 공개 클라이언트 계약이 아니므로 변경 모니터링과 실제 계정 표본 검증이 계속 필요하다.
- Gateway resume 실패 시 jitter와 close code별 재식별 정책을 보강해야 한다.
- read state는 READY snapshot·`MESSAGE_ACK`·`CHANNEL_UNREAD_UPDATE` 수신과 역추적한 `/read-states/ack-bulk` 송신을 양방향 조정하지만 공개 계약이 아니므로 401·403·404 fallback과 변경 모니터링이 필요하다. 실패 시 unread는 로컬 상태를 유지하며 영구적인 100% 동기화를 보증하지 않는다.
- Voice v8, UDP/RTP, Opus, AEAD와 DAVE E2EE 음성 경로 및 시작 시 입력·출력 장치 선택은 구현됐지만 실제 Discord 계정 2개를 사용한 장시간 통화, 통화 중 장치 hot swap, echo cancellation과 noise suppression 검증이 남아 있다.
- 카메라 화상과 Go Live 화면공유 경로는 구현됐지만 실제 Discord SFU와 복수 참가자 환경의 장시간 호환성 검증이 남아 있다.
- PTT는 앱 내 pointer hold와 Windows 전역 F1–F12 key binding, 0–2000ms release delay를 지원한다. 임의 키·마우스 버튼 recording과 관리자 권한으로 실행한 게임에서의 접근은 후속 범위이며, Windows UIPI 제약 때문에 앱과 대상 프로세스의 권한 수준이 다르면 전역 key 상태 확인이 실패할 수 있다.
- 사용자 투표 참여는 역추적한 `/channels/{channel.id}/polls/{message.id}/answers/@me`를 사용한다. 공개 문서가 앱의 투표를 명시적으로 허용하지 않으므로 부계정 실기기 검증과 endpoint 변경 모니터링이 남아 있다.
- channel 고정은 로컬 설정이다. Inbox unread는 서버 read state와 best-effort로 동기화하지만 비공개 계약 변화 시 로컬 값으로 fallback한다.
- 자동 업데이트 배포에는 운영 HTTPS feed와 실제 WinSparkle DSA key pair를 CI secret으로 주입해야 한다. 저장소에는 key를 포함하지 않는다.
- 공식 클라이언트의 private setting인 서버 폴더·사용자 계정 MFA 자격증명 로그인은 안정적인 공개 API가 없어 동일 동작을 보장하지 않는다.

코드·빌드·패키징 마일스톤은 완료됐지만 위 항목은 외부 프로토콜과 운영 환경의 잔여 위험이다. 따라서 공식 클라이언트와의 절대적 feature parity를 보증하지 않는다.

관련 문서: [[Home]], [[Voice]], [[Windows Release]]
