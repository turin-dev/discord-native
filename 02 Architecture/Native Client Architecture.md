---
type: architecture
status: active
tags: [flutter, riverpod, clean-architecture]
source_paths: [lib/app/, lib/core/, lib/features/]
reviewed_at: 2026-07-17
confidence: high
aliases: [Native Client Architecture]
---

# Native Client Architecture

앱은 불변 상태와 경계 인터페이스를 중심으로 구성한다.

- `core/auth`: 토큰 검증, 계정별 secure storage와 다중 계정 session
- `core/gateway`: WebSocket transport, 세션 상태 머신, heartbeat
- `core/network`: JSON·multipart REST executor와 429 재시도
- `features/workspace`: guild/channel/thread/DM reducer, people·presence reducer, direct-message·thread·relationship REST repository, SQLite read-state repository와 데스크톱 shell
- `features/messages`: 메시지·typing 모델, REST repository, 실시간 reducer와 계정별 SQLite 오프라인 캐시
- `features/voice`: Main/Voice Gateway 조정, Voice v8·DAVE 상태 머신, Opus/RTP/UDP 미디어와 VAD·PTT
- `features/system`: 테마·트레이·알림·전역 단축키·업데이트 설정과 Windows bridge
- `features/video`: Discord RTC signaling, Media Foundation 카메라·화면 capture와 H264 render stream
- `app`: Riverpod provider와 앱 수명주기 조정

외부 입력은 JSON 경계에서 검증하고, reducer는 기존 객체를 수정하지 않고 새 상태를 반환한다. Gateway 연결은 connection별 공유 inflater를 사용하는 `zlib-stream` transport compression을 적용하고 READY 뒤 guild를 80개씩 묶어 OP37 member·presence subscription을 보낸다. READY의 private channel은 synthetic `@me` guild 아래 type 1/3 channel로 정규화해 기존 메시징 흐름을 재사용한다. guild channel은 type 4 category, category child, channel child thread 순으로 불변 정렬한다. 친구에게 새 DM을 열 때 direct-message repository가 반환한 channel을 같은 workspace에 upsert하고 `@me` guild와 channel을 선택한다. people reducer는 relationship type 1–5, guild member, partial user와 presence를 독립적인 불변 상태로 병합한다. relationship 변경은 전용 repository와 controller extension에 격리하고 REST 성공 뒤 people state를 낙관적으로 교체하며, 실패는 friend panel의 사용자 친화적 오류로 변환한다. 메시지 모델은 mention, embed, sticker와 custom emoji 원문을 보존하고 표시용 markdown을 별도로 생성한다. 렌더러는 markdown parser의 custom inline syntax로 spoiler를 상태형 widget에 매핑하고 네트워크 미디어는 캐시 계층을 사용한다. 첨부 업로드는 플랫폼 picker에서 바이트와 MIME type으로 정규화한 뒤 repository의 개수·크기 경계를 통과하며, 다운로드는 save dialog와 Discord CDN HTTPS allowlist를 거친다. thread는 channel type 10/11/12와 metadata를 동일 workspace 상태에 보존하며 parent channel 아래에 정렬한다. 검색 상태는 메시지 목록과 분리해 비동기 검색 경쟁을 격리하고, 결과 선택 시 해당 message 주변 컨텍스트를 별도로 로드한다. 과거 message page는 earliest ID를 `before` cursor로 사용하고 기존 목록에 중복 없이 병합한다. MESSAGE_UPDATE는 누락 가능한 필드를 기존 message와 병합해 author와 timestamp를 보존한다. TYPING_START는 별도 불변 상태에 저장하고 cancel 가능한 scheduler가 10초 후 만료시키며, composer의 REST typing 요청은 8초 동안 throttle한다. 메시지 작업 dialog, rich content renderer, composer, pagination control과 search/member/friend right panel은 workspace shell에서 분리한다. 앱 상태 모델, Gateway event pipeline과 typing·relationship controller extension도 orchestration 본체에서 분리한다. 채널별 last-read ID와 unread count는 직렬화된 SQLite upsert로 저장해 재시작 후 복원한다.

음성은 Main Gateway의 server/session event reducer와 Voice Gateway·미디어 연결을 `DiscordVoiceCoordinator`에서 결합한다. Voice WebSocket Resume은 UDP와 DAVE session을 유지하고, session 만료에 따른 fresh Identify는 기존 미디어 엔진 정리를 완료한 뒤 새 암호화 session으로 교체한다.

시스템 통합은 추상 bridge와 불변 설정 상태를 통해 플랫폼 채널을 앱 로직에서 격리한다. 저장 계정 인덱스와 계정별 토큰 key를 분리하고, 계정 전환 시 Gateway·음성·화면 상태를 먼저 정리한다. 메시지 오프라인 캐시는 별도 SQLite DB에서 `(account_id, channel_id, message_id)` 경계로 분리하며 REST 실패 시에만 현재 scope를 복원한다.

Windows attachment video는 `video_player_win`의 Media Foundation backend를 사용한다. 음성 playback과 Discord Opus codec은 `flutter_soloud`에 포함된 `opus.dll`을 공유하고, Release CMake는 사용하지 않는 Xiph decoder DLL을 링크하지 않는다. Release build는 AOT symbol 분리와 Material icon subset을 거친 뒤 benchmark·installer·update signature 단계로 전달된다.

관련 문서: [[Gateway and Messaging]], [[Voice]], [[Desktop System Integration]], [[Authentication to Messaging]], [[Windows Development]], [[Windows Release]]
