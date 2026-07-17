---
type: module
status: active
tags: [gateway, rest, messages]
source_paths: [lib/core/gateway/, lib/core/network/, lib/features/messages/, lib/features/workspace/data/, lib/features/workspace/presentation/]
reviewed_at: 2026-07-17
confidence: high
aliases: [Gateway and Messaging]
---

# Gateway and Messaging

`DiscordGatewayClient`는 Gateway v10 JSON WebSocket을 `zlib-stream` transport compression으로 열고 HELLO, IDENTIFY, heartbeat, ACK, READY 세션 정보를 처리한다. IDENTIFY의 비공개 `client_state`는 모든 version을 초기값으로 보내 cold snapshot을 요청하며, versioned read state capability와 함께 READY의 전체 읽음 기준을 받는다. connection마다 공유 inflater를 유지하고 `00 00 FF FF` flush marker가 완성된 시점에 payload를 복원한다. OP7과 transport 오류에서는 `resume_gateway_url`로 재접속해 OP6 RESUME을 시도하고, heartbeat ACK 누락은 즉시 연결을 교체한다. 일반 transport 오류는 1초부터 최대 30초까지 지수 backoff를 적용한다. READY 뒤에는 최대 80개 guild 단위 OP37 subscription으로 typing, thread, activity와 member update를 요청한다. dispatch payload는 workspace, people, typing과 message reducer로 전달한다.

`DiscordRestClient`는 인증 토큰을 요청 경계에만 주입하고 429 응답의 `retry_after`를 최대 세 번 재시도한다. JSON 요청과 `payload_json`·`files[n]` 구조의 multipart 요청을 구분해 Dio가 multipart boundary를 생성하도록 한다. `DiscordMessageRepository`는 채널 히스토리를 시간순으로 정규화하고 2000자 메시지, 최대 10개·총 25 MiB 첨부 경계를 검증한다. 일반 답장과 첨부 답장 reference, reaction PUT/DELETE, 메시지 PATCH/DELETE, 새 `/messages/pins/{message.id}` 고정 endpoint와 `/typing` POST도 같은 경계에서 처리한다. 투표는 질문 1–300자, 답변 2–10개와 각 1–55자, 1–768시간 duration을 검증한 뒤 Create Message의 `poll` payload로 전송한다. 사용자 투표는 역추적한 `PUT /channels/{channel.id}/polls/{message.id}/answers/@me`에 정렬된 `answer_ids`를 보내며, 빈 배열은 기존 선택을 모두 취소한다. `DiscordDirectMessageRepository`는 `/users/@me/channels`에 recipient ID를 보내 기존 또는 새 DM channel을 반환한다. `DiscordRelationshipRepository`는 username 입력을 trim·길이 검증한 뒤 친구 요청을 보내고, user ID 기준 친구 요청 수락·차단·관계 삭제를 처리한다.

현재 지원 dispatch:

- READY
- GUILD_CREATE, GUILD_UPDATE, GUILD_DELETE
- GUILD_ROLE_CREATE, GUILD_ROLE_UPDATE, GUILD_ROLE_DELETE
- GUILD_EMOJIS_UPDATE, GUILD_STICKERS_UPDATE
- GUILD_SCHEDULED_EVENT_CREATE, GUILD_SCHEDULED_EVENT_UPDATE, GUILD_SCHEDULED_EVENT_DELETE
- CHANNEL_CREATE, CHANNEL_UPDATE, CHANNEL_DELETE
- THREAD_CREATE, THREAD_UPDATE, THREAD_DELETE, THREAD_LIST_SYNC
- MESSAGE_CREATE, MESSAGE_UPDATE, MESSAGE_DELETE
- MESSAGE_POLL_VOTE_ADD, MESSAGE_POLL_VOTE_REMOVE
- MESSAGE_ACK, CHANNEL_UNREAD_UPDATE
- TYPING_START
- GUILD_MEMBER_ADD, GUILD_MEMBER_UPDATE, GUILD_MEMBER_REMOVE, GUILD_MEMBERS_CHUNK
- GUILD_MEMBER_LIST_UPDATE, PRESENCE_UPDATE
- RELATIONSHIP_ADD, RELATIONSHIP_UPDATE, RELATIONSHIP_REMOVE

READY private channel의 recipient를 이용해 1:1 DM 이름을 만들고 group DM 이름·recipient를 보존한다. 친구 목록의 메시지 버튼은 `Create DM` 응답을 workspace에 upsert하고 해당 channel의 최근 메시지를 즉시 불러온다. 관계 type 1–5는 친구, 차단, 받은 요청, 보낸 요청과 implicit 관계로 해석하며 READY·RELATIONSHIP dispatch를 병합한다. 친구 panel은 친구 추가·요청 수락·거절·취소, 차단·해제·삭제를 제공하고 파괴적 관계 변경은 확인 dialog를 거친다. REST 성공 뒤 people state를 새 관계 type 또는 제거된 목록으로 교체하며 이후 RELATIONSHIP dispatch가 서버 상태를 재동기화한다. guild member는 role ID, nickname, timeout, user와 presence를 보존하고 PRESENCE_UPDATE의 partial user를 기존 user와 합친다. guild role과 channel overwrite permission 문자열은 `BigInt`로 읽는다. 권한 계산은 owner·ADMINISTRATOR 우회, @everyone과 member role 합산, @everyone·role·member overwrite, thread parent 상속, timeout mask 순서를 적용한다. role 정보와 현재 member를 모두 확보한 뒤에만 채널 노출, 메시지 전송, 다른 사용자 메시지 삭제와 pin UI를 계산 결과로 제한하며 초기 동기화 중에는 Gateway 목록을 유지한다. `MANAGE_CHANNELS`, `MANAGE_ROLES`, `MANAGE_GUILD`, `MANAGE_EVENTS` 권한은 각각 channel, role, invite, scheduled event 서버 설정 UI를 연다. channel 생성·수정·삭제, role 생성·수정·순서 변경·삭제, invite 조회·생성·복사·삭제를 REST와 연결하며 forum channel은 thread API로 tag가 적용된 post를 만든다. scheduled event는 Gateway 상태와 guild REST 목록을 병합하고 위치·시작·종료 시각을 가진 external event 생성·수정·상태 변경·삭제를 제공한다. 메시지 모델은 referenced message, attachment 메타데이터, reaction 집계, mention, embed, sticker, poll과 pinned 상태를 보존한다. GUILD_CREATE와 expression update dispatch에서 사용 가능한 custom emoji·guild sticker를 보존하고 composer picker는 Unicode emoji 또는 `<:NAME:ID>`·`<a:NAME:ID>` 문법을 커서 위치에 삽입한다. sticker 선택은 Create Message의 `sticker_ids`로 전송한다. `DiscordMessageContent`는 GFM, inline·fenced code, spoiler, user·role·channel mention, custom emoji, embed field·image와 PNG·APNG·Lottie·GIF sticker media를 렌더링하며 Lottie에는 raster render cache를 적용한다. attachment image와 embed media는 캐시하고 video attachment는 `video_player_win`의 Media Foundation player와 desktop controls로 재생한다. poll question·answer·emoji·집계·내 선택·종료 상태는 불변 모델로 파싱하고 conversation card에서 렌더링한다. card 선택은 전송 중 잠기며 REST 성공 뒤 즉시 로컬 집계를 갱신하고, poll vote Gateway dispatch는 현재 사용자 이벤트를 중복 집계하지 않으면서 다른 사용자의 표를 실시간 반영한다. `DiscordAttachmentDownloadService`는 filename을 정규화하고 `cdn.discordapp.com`·`media.discordapp.net` HTTPS만 native save dialog 경로로 내려받는다. initial page가 50개면 earliest message ID를 `before`로 보내 다음 page를 읽고 ID 기준으로 중복 제거한 뒤 시간순으로 병합한다. partial MESSAGE_UPDATE는 payload에 존재하는 필드만 기존 message에 병합하고 MESSAGE_DELETE는 즉시 목록에서 제거한다. `DiscordTypingState`는 자신을 제외한 channel별 typing 사용자를 member 이름과 10초 만료 시점으로 보존하며, MESSAGE_CREATE 또는 scheduler 만료가 사용자를 제거한다. `FilePickerAttachmentPicker`는 Windows 파일 선택 결과를 불변 `DiscordUploadFile` 목록으로 변환하고 MIME type을 판별한다. `DiscordThreadRepository`는 active guild thread와 public·joined private archived thread를 합치고 공개 thread 생성, 메시지에서 시작, 참여, 보관·해제를 처리한다. guild 메시지 검색은 content와 선택적 channel filter를 전달하고, 색인 준비 응답 코드 `110000`은 `retry_after` 뒤 최대 두 번 재시도한다. 검색 결과의 thread를 workspace에 병합하고 선택한 message는 `around` 조회로 컨텍스트를 연다. 비선택 channel의 MESSAGE_CREATE는 로컬 unread count를 증가시키고 channel 진입·전송·선택 channel 수신은 last-read를 갱신한다. `DiscordClientSyncRepository`는 이 로컬 전이를 역추적한 `POST /read-states/ack-bulk`와 직렬화해 공식 클라이언트에도 전달한다. 반대 방향은 READY `read_state` snapshot, 다른 기기의 `MESSAGE_ACK`, `GUILD_CREATE`·`CHANNEL_UNREAD_UPDATE`의 최신 message ID를 조정한다. 서버와 로컬 cursor가 충돌하면 더 최신 snowflake를 유지해 서버에 다시 ACK하고, `manual: true` ACK는 의도적인 unread 이동으로 받아들인다. 401·403·404가 발생하면 세션 동안 재시도를 중단하고 로컬 상태는 보존한 채 workspace 경고를 표시한다. 이 경로는 비공개 계약이므로 관측 가능한 양방향 경로를 구현했어도 영구적인 100% 동기화를 보증하지 않는다. 관련 외부 제약은 [[Open Questions]]를 본다.
