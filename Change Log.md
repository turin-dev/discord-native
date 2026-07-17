---
type: change-log
status: active
tags: [changes]
source_paths: [lib/, test/, windows/, third_party/, tool/]
reviewed_at: 2026-07-17
confidence: high
aliases: [Change Log]
---

# Change Log

## 2026-07-17

- Discord 2025 desktop 정보 구조를 반영한 system/light/ash/dark/onyx palette와 compact/default/spacious 표시 밀도 구현
- 220–360px channel sidebar resize·영속화, local channel pin section과 guild/channel 뒤로·앞으로 history 구현
- title bar Inbox·도움말 action을 로컬 unread state와 실제 dialog에 연결
- Discord Create Message poll payload 검증·전송, poll 응답 파싱·집계 card와 composer 생성 dialog 구현
- Windows 입력·출력 오디오 장치 열거, 설정 저장과 `record`·SoLoud 초기화 장치 선택 구현
- workspace 전체 surface를 ThemeExtension palette로 전환해 light/ash/dark/onyx 대비 일관성 보정
- analyzer 0건, 337개 테스트와 80.28% line coverage 검증
- 전체 구현 소스를 독립된 공개 저장소 이력으로 복제하고 로컬 IDE·build·coverage artifact 제외
- 빌드에 사용하지 않는 mbedTLS private-key test fixture와 upstream 개인 경로가 담긴 생성 파일 제거
- gitleaks 기본 규칙과 검토된 vendored test vector allowlist를 추가하고 전체 Git 이력 0건 검증
- MIT 프로젝트 라이선스, third-party 고지, 기여·보안 정책, issue·pull request template 추가
- 공개용 README, Windows setup script, Dependabot과 signed release secret 안내 추가
- Dart 3.12 전용 package가 Flutter 3.41.9 CI에 제안되지 않도록 Dependabot 호환 범위 고정
- 존재하지 않는 category를 참조하는 channel도 목록에서 보존하도록 정렬 보정
- guild owner·role과 channel permission overwrite 모델 및 role Gateway event 구현
- owner·ADMINISTRATOR·role/member overwrite·thread 상속·timeout을 포함한 `BigInt` permission 계산 구현
- 현재 member 권한에 따른 채널 노출, 메시지 전송, 다른 사용자 메시지 삭제와 pin UI 게이팅 구현
- workspace navigation을 별도 presentation 파일로 분리
- guild channel 생성·수정·삭제와 text·category·announcement·forum 유형 설정 구현
- guild role 생성·수정·순서 변경·삭제와 권한 편집 구현
- guild invite 조회·생성·복사·삭제 구현
- forum post 목록·tag 표시·작성과 thread API 연결 구현
- scheduled event Gateway reducer와 external event 조회·생성·수정·상태 변경·삭제 구현
- 권한별 서버 설정 role·invite·event 탭 게이팅 구현
- GUILD_CREATE와 expression update dispatch의 custom emoji·guild sticker 상태 구현
- standard/custom emoji composer picker와 guild sticker 메시지 전송 구현
- `media_kit` 기반 Windows 첨부 영상 재생과 desktop controls 구현
- owner·ADMINISTRATOR가 channel overwrite deny를 우회하도록 permission 계산 보정
- 158개 테스트, line coverage 85.12%, Windows debug build 검증
- Voice Gateway v8, UDP IP discovery, RTP AEAD와 DAVE v1 MLS session 구현
- native libopus encode/decode, 48 kHz stereo microphone capture와 사용자별 SoLoud playback 구현
- VAD·PTT, mute·deafen, 사용자별 0–200% 음량과 5개 Opus silence frame 종료 구현
- Voice OP7 buffered Resume, heartbeat ACK 복구, 세션 만료 fresh Identify와 지수 backoff 구현
- 229개 테스트, line coverage 80.78%, Windows debug build와 native DLL·license bundle 검증
- Voice Gateway WebRTC signaling, DAVE H264 보호·해제와 native `libdatachannel` bridge 구현
- Windows Media Foundation H264 카메라 encoder·원격 decoder와 사용자별 video tile 구현
- Go Live OP18·OP22·OP20·OP19, 별도 RTC 방송 연결과 receive-only 시청 연결 구현
- 카메라·화면 capture 분리, 화면 공유 pause/resume와 방송 참가자 시청 UI 구현
- 268개 테스트, line coverage 80.02%, Windows debug build 검증
- Windows 트레이 최소화·창 복원, 로컬 알림·소리, `Ctrl+Shift+D` 전역 단축키와 HTTPS 피드 기반 자동 업데이트 구현
- system/light/dark 테마, 사용자 강조 색상과 시스템 기능별 설정 저장 구현
- 계정 메타데이터와 secure token key를 분리한 다중 계정 저장·전환·삭제 구현
- 계정·채널별 SQLite 메시지 캐시와 REST 실패 시 오프라인 복원, Gateway 증분 동기화 구현
- 현재 사용자·열린 채널을 제외한 MESSAGE_CREATE 네이티브 알림 구현
- 313개 테스트, line coverage 80.02%, Windows debug build와 데스크톱 플러그인 링크 검증
- 첨부 영상 backend를 Windows Media Foundation 기반 `video_player_win`으로 교체하고 재생·seek·mute·전체 화면 제어 구현
- `flutter_soloud`의 `opus.dll`을 Discord Opus FFI와 공유하고 사용하지 않는 FLAC/Vorbis/Ogg DLL 배포 제거
- AOT debug symbol 분리와 Material icon 72 glyph subset으로 Release 설치 디렉터리를 59.05MB까지 축소
- 시작 0.200초, working set 99.60MB, 유휴 CPU 0%, 설치 크기 59.05MB를 측정·강제하는 Windows benchmark harness 구현
- analyzer·320개 테스트·80.48% line coverage·Release build·benchmark·portable artifact를 검증하는 Windows CI 구현
- per-user Inno Setup installer, SHA-256, WinSparkle DSA 서명과 HTTPS appcast 생성 파이프라인 구현
- 19.93MB Windows installer와 서명 appcast end-to-end 검증
- Discord 데스크톱과 같은 32/72/240/48/240 workspace shell과 중앙 전역 검색 구현
- CDN guild icon·user avatar와 deterministic fallback identity component 구현
- 34px channel row, unread·selected 상태, 52px user control panel과 실제 mute·deafen action 구현
- message 최신 항목 하단 정렬, hover action toolbar와 안정적인 anchored action menu 구현
- 검색 활성화 시 right panel 자동 전환, 기본 guild member panel과 DM friend panel 동작 정리
- Discord형 composer·channel header·login card와 공통 design token 계약 구현
- UI 계약 문서, JSON token과 자체 포함 HTML preview 추가
- analyzer·321개 테스트·80.62% line coverage 검증

## 2026-07-16

- Flutter Windows 프로젝트와 Git 기준선 생성
- secure token storage와 Gateway heartbeat 상태 머신 구현
- guild/channel workspace UI 구현
- REST 429 재시도와 텍스트 메시지 조회·전송 구현
- Riverpod 앱 수명주기와 로그아웃 구현
- Visual Studio 2026 CMake file tracker 우회 적용
- Gateway RESUME, heartbeat timeout 복구, 지수 backoff 구현
- Gateway zlib-stream 공유 inflater와 chunk 경계 처리 구현
- reply, attachment 메타데이터, reaction 표시·추가·제거 구현
- Windows 파일 선택, multipart 첨부 업로드와 첨부 답장 구현
- active·archived thread 목록, 생성, 메시지 시작, 참여, 보관·해제 구현
- guild 메시지 검색, channel filter, 색인 재시도와 around 컨텍스트 로드 구현
- SQLite 기반 last-read·unread 복원, MESSAGE_CREATE 계산과 channel badge 구현
- 소유 메시지 편집·삭제, 메시지 고정·해제와 partial MESSAGE_UPDATE 병합 구현
- 메시지 작업 dialog와 composer를 workspace shell에서 분리
- `before` cursor 기반 과거 메시지 페이지네이션과 중복 제거 병합 구현
- TYPING_START 표시·10초 만료·MESSAGE_CREATE 제거와 REST 8초 throttle 구현
- 앱 상태, typing controller extension과 pagination control 분리
- READY private channel 기반 1:1·group DM 대화와 synthetic `@me` guild 구현
- 친구·요청·차단 목록, guild member·presence reducer와 profile card 구현
- READY 이후 OP37 guild member·presence subscription 구현
- Gateway event pipeline과 search/member/friend right panel 분리
- 친구 추가·수락·거절·취소, 차단·해제·삭제와 확인 dialog 구현
- 친구 목록에서 `Create DM`으로 1:1 DM channel을 생성·재사용하고 즉시 선택하는 흐름 구현
- Discord markdown, 코드블록, 스포일러와 mention 표시 구현
- embed field·이미지, custom emoji CDN 이미지와 PNG/APNG/GIF sticker 렌더링 구현
- 첨부 이미지 캐시 미리보기와 save dialog 기반 Discord CDN HTTPS 다운로드 구현
- raster render cache를 적용한 Lottie sticker 렌더링 구현
- category와 하위 channel·thread 트리 정렬·표시 구현
- 118개 테스트, line coverage 83.60%, Windows debug build 검증

관련 문서: [[Home]], [[Voice]], [[Windows Release]]
