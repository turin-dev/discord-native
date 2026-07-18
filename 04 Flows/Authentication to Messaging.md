---
type: flow
status: active
tags: [auth, gateway, messaging]
source_paths: [lib/app/discord_app_controller.dart, lib/features/auth/, lib/features/messages/, lib/features/workspace/, lib/features/system/]
reviewed_at: 2026-07-18
confidence: high
aliases: [Authentication to Messaging]
---

# Authentication to Messaging

1. 앱 시작 시 secure storage에서 저장 토큰을 읽는다.
2. 토큰이 없거나 손상됐으면 위험 고지가 포함된 로그인 화면을 표시한다.
3. Gateway 연결 후 HELLO를 받으면 IDENTIFY를 보내고 heartbeat를 예약한다.
4. 연결 손실 시 세션이 유효하면 RESUME하고, 그렇지 않으면 backoff 후 새 IDENTIFY를 수행한다.
5. READY/GUILD/CHANNEL dispatch가 workspace 상태를 구성한다.
6. READY private channel과 relationship이 있으면 synthetic `@me` guild를 만들고 첫 DM을 선택한다. 현대 payload의 최상위 `users`와 `recipient_ids`를 ID로 결합하며 예전 embedded `recipients`도 허용한다.
7. `@me`에서는 320px DM navigation과 친구 홈을 표시한다. 1:1 DM은 participant panel 없이 열고 group DM은 recipient와 현재 사용자를 결합한 멤버 panel을 표시한다.
8. guild 선택 시 첫 text channel을 선택하고 REST로 최근 메시지 50개를 읽는다.
9. 사용자가 과거 메시지를 요청하면 earliest ID를 `before` cursor로 보내 다음 50개를 중복 없이 앞에 병합한다.
10. READY 뒤 OP37 subscription을 보내 member·presence update를 요청한다.
11. GUILD_MEMBER, GUILD_MEMBER_LIST_UPDATE와 PRESENCE_UPDATE를 member 목록에 병합한다.
12. READY·RELATIONSHIP dispatch를 친구·요청·차단 목록에 병합하고 profile card로 표시한다.
13. 친구 목록의 메시지 버튼은 `Create DM`을 호출하고 반환 channel을 synthetic `@me` guild에 병합한 뒤 최근 메시지를 연다.
14. 친구 panel은 username 친구 추가, 받은 요청 수락·거절, 보낸 요청 취소와 친구 차단·삭제·차단 해제를 relationship REST repository로 보낸다.
15. 파괴적 관계 변경은 확인 dialog를 거치며 성공 뒤 새 people state를 즉시 표시하고 후속 RELATIONSHIP dispatch로 재동기화한다.
16. MESSAGE dispatch를 현재 채널 상태에 합친다.
17. composer는 일반 메시지·답장·투표를 전송하고 REST 응답을 즉시 현재 목록에 추가한다.
18. composer 입력은 `/typing` 요청으로 전달하되 8초 동안 중복 호출을 억제한다.
19. TYPING_START는 자신을 제외하고 표시하며 새 message 또는 10초 만료 시 제거한다.
20. 파일 선택 결과는 MIME type과 바이트로 정규화되며, 최대 10개·총 25 MiB 검증 후 `payload_json`과 `files[n]` multipart 요청으로 전송된다.
21. 첨부가 포함된 답장은 동일 multipart payload에 message reference를 보존한다.
22. 수신 message의 markdown, 코드, spoiler, mention, custom emoji, embed와 sticker는 rich content renderer로 전달된다.
23. 첨부 이미지는 캐시 미리보기를 표시하고 다운로드는 native save dialog 뒤 Discord CDN HTTPS allowlist를 검증한다.
24. active·archived thread 목록은 parent channel 아래에 병합되고 Gateway THREAD dispatch로 갱신된다.
25. 사용자는 공개 thread를 만들거나 메시지에서 시작하고, thread 참여와 보관·해제를 수행한다.
26. guild 검색 panel은 guild 전체 또는 현재 channel을 검색한다. DM header 검색은 선택한 private channel만 조회하고 활성화된 동안 멤버 panel을 검색 결과 panel로 교체한다. 색인 준비 중이면 서버가 지정한 시간 뒤 재시도한다.
27. 검색 결과를 선택하면 해당 channel의 message 주변 50개를 `around`로 읽어 대화 컨텍스트를 표시한다.
28. 비선택 channel의 새 message는 로컬 unread count를 증가시키고 channel 진입·전송·선택 channel 수신은 unread를 지운다.
29. last-read ID와 unread count는 SQLite에 직렬 upsert되고 앱 재시작 시 복원된다.
30. 소유 메시지는 작업 메뉴에서 편집·삭제하고, 모든 표시 메시지는 고정·해제 endpoint로 라우팅한다.
31. guild·DM header의 pin action은 현재 channel의 고정 메시지를 50개씩 읽고 240px panel에 표시한다. 더 읽기는 ISO 8601 `before` cursor를 사용한다.
32. 고정 메시지를 선택하면 해당 message 주변 50개를 `around`로 열고, 해제·삭제와 다른 기기의 CHANNEL_PINS_UPDATE는 열린 panel을 즉시 동기화한다.
33. REST 응답은 즉시 불변 message state에 반영하고 partial MESSAGE_UPDATE와 MESSAGE_DELETE dispatch가 후속 상태를 동기화한다.
34. reaction 선택은 현재 사용자의 추가·제거 endpoint로 라우팅한다.
35. title bar는 방문한 channel history의 뒤로·앞으로 이동과 로컬 unread Inbox를 제공한다.
36. channel 고정, sidebar 폭, 표시 밀도와 테마는 desktop 설정에 저장해 다음 실행에 복원한다.
37. 로그아웃은 secure storage, 로컬 read state와 Gateway 연결을 정리한다.

오류는 사용자 친화적 상태로 변환하며 토큰을 로그에 기록하지 않는다.

관련 문서: [[Gateway and Messaging]], [[Native Client Architecture]], [[Windows Development]]
