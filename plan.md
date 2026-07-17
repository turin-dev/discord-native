# 디스코드 윈도우 네이티브 앱 만들기

> **구현 상태 (2026-07-17):** Phase 0~8 코드, 자동 검증, 성능 gate, Windows installer와 서명 appcast 파이프라인 완료. 공식 private API와 실계정 장시간 호환성은 [[Open Questions]]의 외부 제약으로 관리한다.

공식 Discord(Electron) 클라이언트를 **완전 대체**하는 Flutter 기반 Windows 네이티브 클라이언트.
목표는 **전 기능 동등(feature parity) + 압도적 최적화**.

---

## 1. 목표 & 배경

**요지: Discord 서버·프로토콜은 그대로 두고, Electron으로 된 "클라이언트만" Flutter로 재구성(포팅)한다.**
백엔드/API를 새로 만드는 것이 아니라, 공식 클라이언트가 하는 일(Gateway 연결·REST 호출·음성 UDP)을
Flutter 네이티브 UI/로직으로 동일하게 다시 구현하는 작업이다.

- 공식 Discord는 **Electron**(Chromium + Node)이라 메모리 과다·기동 지연·CPU 낭비가 심하다.
- 동일 기능을 **Flutter 네이티브**로 재구현해:
  - **메모리 절반 이하**, **콜드 스타트 2~3배 단축**, **유휴 CPU 최소화**를 달성한다.
  - 공식 클라이언트의 **모든 기능**(서버·DM·음성·화상·화면공유·알림 등)을 빠짐없이 지원한다.
- "가벼운 서브셋"이 아니라 **일상 사용을 완전히 대체**할 수 있는 수준을 지향한다.

### 성능 목표(측정 기준)
| 지표 | 공식(Electron) 기준 | 목표 |
|------|--------------------|------|
| 유휴 메모리 | 400~700MB+ | **< 200MB** |
| 콜드 스타트 | 3~6초 | **< 1.5초** |
| 유휴 CPU | 1~3% | **< 0.5%** |
| 설치 용량 | 150MB+ | **< 60MB** |

---

## 2. ⚠️ 사전 고지 — ToS 리스크 (완전 대체의 전제)

"모든 기능을 갖춘 완전 대체 클라이언트"는 필연적으로 **사용자 계정 토큰**으로
Discord Gateway/REST에 접속한다. 이는 공식 **이용약관(ToS) 위반**(서드파티 클라이언트/셀프봇)이며
**계정 정지·삭제 위험**을 수반한다. Bot API로는 DM·친구·음성 등 개인 기능을 대체할 수 없어
"완전 대체" 목표와 양립하지 않는다.

**진행 전제(사용자 확정)**:
- 개인 사용 목적, **본인 계정 책임 하에** 진행한다.
- 공개 배포/상업화는 하지 않으며, 리스크를 인지하고 감수한다.
- 가능하면 **부계정으로 먼저 검증**한 뒤 본계정에 적용한다.

> 이 리스크는 기술로 제거할 수 없다. 계획은 이를 명시한 채 완전 대체 구현을 진행한다.

---

## 3. 기술 스택

| 영역 | 선택 | 이유 |
|------|------|------|
| UI | **Flutter (Windows desktop)** | 네이티브 렌더링, 저메모리, 60/120fps |
| 언어 | Dart 3.x | Flutter 표준 |
| 상태관리 | Riverpod | 테스트 용이, 세밀한 리빌드 제어(성능) |
| REST | `dio` + 레이트리밋 인터셉터 | 버킷 큐잉, 재시도 |
| Gateway | `web_socket_channel` + zlib-stream 해제 | 실시간 이벤트 |
| 음성/화상 | **`flutter_webrtc`** + Discord Voice UDP | 통화·화면공유 핵심 |
| 오디오 코덱 | Opus (`dart_opus`/FFI) | Discord 음성 필수 |
| 로컬 DB | `sqflite_common_ffi`(SQLite) | 메시지/캐시, 오프라인, 빠른 쿼리 |
| 시크릿 | `flutter_secure_storage` | 토큰 암호화 |
| 모델 | `freezed` + `json_serializable` | 불변 모델 |
| 라우팅 | `go_router` | 선언적 네비게이션 |
| 이미지/캐시 | `cached_network_image` | 아바타·임베드 성능 |
| 네이티브 연동 | Windows plugin / FFI | 트레이·토스트·창·미디어·코덱 |

---

## 4. 아키텍처

Clean Architecture + 기능별 모듈. **불변 데이터 / Repository 패턴 / 유스케이스** 원칙.

```
lib/
├── core/            # 네트워크, 에러, 상수, 테마, 성능 유틸
│   ├── network/     #  REST client, Gateway(WS), Voice(UDP/WebRTC)
│   ├── config/      #  엔드포인트, 환경설정
│   └── error/       #  예외/Result 래퍼
├── data/            # DTO, 데이터소스(remote/local), Repository 구현
├── domain/          # 엔티티, Repository 인터페이스, 유스케이스
├── features/        # 기능별 UI + 상태
│   ├── auth/        │ guilds/    │ channels/  │ messages/
│   ├── dms/         │ voice/     │ video/     │ members/
│   ├── notifications/ │ search/  │ settings/  │ friends/
└── main.dart
```

- **성능 원칙**: 가상 스크롤(`ListView.builder`)·이미지 lazy·이벤트 디바운스·선택적 리빌드.
- **동시성**: 무거운 파싱/압축 해제는 `Isolate`에서 처리(UI 스레드 블로킹 방지).

---

## 5. Discord 프로토콜 연동

### 5.1 인증
- 사용자 토큰을 `flutter_secure_storage`에 암호화 저장(하드코딩·평문 금지).
- 로그인: 토큰 직접 입력 / (선택) 임베디드 로그인 웹뷰로 토큰 취득.
- MFA 계정 흐름 대응.

### 5.2 Gateway (실시간, v10)
- WSS 연결 → `HELLO` → `IDENTIFY` → `READY`.
- **Heartbeat**: interval 주기 OP1 전송 + ACK 감시.
- **재연결/RESUME**: 지수 백오프, 세션 무효 시 재-IDENTIFY.
- **압축**: `zlib-stream` 트랜스포트 압축 해제(Isolate).
- 이벤트: `MESSAGE_*`, `GUILD_*`, `CHANNEL_*`, `PRESENCE_UPDATE`, `TYPING_START`, `VOICE_STATE/SERVER_UPDATE` 등 전 이벤트 처리.

### 5.3 REST (v10)
- Base `https://discord.com/api/v10`.
- 레이트리밋: `X-RateLimit-*` 버킷 큐잉, 429 `retry_after` 대기, 글로벌 리밋 처리.

### 5.4 음성/화상 (핵심 난제)
- **Voice Gateway(WSS)** 로 세션/암호화 키 협상 → **UDP** 로 Opus 오디오 송수신.
- 암호화: `xsalsa20_poly1305`(libsodium/FFI).
- 화상·화면공유: WebRTC 경로 조사 후 채택.
- 에코 제거/노이즈 억제/입력감지(VAD).

---

## 6. 전체 기능 목록 (Feature Parity 체크리스트)

완전 대체를 위해 아래를 **모두** 구현한다.

### 메시징
- [x] 텍스트 채널 메시지 송수신(실시간)
- [x] 마크다운·코드블록·스포일러 렌더링
- [x] 임베드·링크 프리뷰·첨부(이미지/영상/파일) 업/다운로드
- [x] 이모지·커스텀 이모지·스티커·리액션
- [x] 답장(reply)·멘션·역할 멘션·에브리원
- [x] 메시지 편집/삭제/고정(pin)
- [x] 스레드(thread)
- [x] 타이핑 인디케이터, 읽음/미읽음, 안읽은 배지
- [x] 메시지 검색·channel filter·주변 context, member·attachment metadata 탐색

### 서버(길드)
- [x] 서버 목록 레일과 READY 순서 유지
- [x] 채널/카테고리 트리, 권한별 표시
- [x] 멤버 목록·역할·프레즌스(온라인/자리비움/DND)
- [x] 서버 설정/역할/초대(관리 기능)
- [x] 포럼 채널·공지 채널·이벤트

### DM / 친구
- [x] 1:1 DM, 그룹 DM
- [x] 친구 목록·추가·차단·요청
- [x] 사용자 프로필 카드

### 음성/화상
- [x] 음성 채널 참가/퇴장, 마이크/헤드셋 뮤트
- [x] 화상 통화(카메라)
- [x] 화면 공유(Go Live)
- [x] 입력 감지/푸시투토크, 음량 조절, 사용자별 볼륨

### 시스템/UX
- [x] 네이티브 알림(Windows 토스트)·소리
- [x] 시스템 트레이 상주·최소화
- [x] 라이트/다크 테마, 커스텀 액센트
- [x] 전역 단축키, activity 기반 Rich Presence 표시
- [x] 다중 계정 전환
- [x] 오프라인 캐시·자동 재연결
- [x] DSA 서명 appcast 기반 자동 업데이트

---

## 7. 구현 단계 (Phase)

각 단계 **TDD**(RED→GREEN→IMPROVE), 커버리지 80%+, 단계별 **성능 벤치마크** 기록.

### Phase 0 — 셋업 & 벤치 기준선
- [x] Flutter Windows 활성화, 프로젝트/폴더 스캐폴딩, 린트
- [x] CI(분석·테스트·빌드), 시크릿 관리
- [x] **성능 측정 하네스**(메모리/기동/CPU) 구축 → 기준선 확보

### Phase 1 — 인증 & 실시간 연결
- [x] secure token 저장/로그인과 MFA 완료 session token 처리
- [x] REST client + 레이트리밋
- [x] Gateway 연결·Heartbeat·RESUME·zlib-stream
- [x] 연결 상태 UI

### Phase 2 — 서버·채널·멤버
- [x] 길드/채널/카테고리/멤버/역할/프레즌스
- [x] 서버 레일·채널 사이드바·멤버 리스트 UI

### Phase 3 — 메시징 (핵심)
- [x] 히스토리 페이지네이션·실시간 송수신
- [x] 마크다운·임베드·첨부·이모지·리액션·답장·편집/삭제
- [x] 스레드, 타이핑, 읽음 상태, 로컬 캐시

### Phase 4 — DM & 친구
- [x] DM·그룹 DM, 친구/차단/요청, 프로필 카드

### Phase 5 — 음성 (최고 난도)
- [x] Voice Gateway 협상 + UDP Opus 송수신 + AEAD/DAVE
- [x] 뮤트/음량/VAD/푸시투토크

### Phase 6 — 화상 & 화면공유
- [x] 카메라 화상, Go Live 화면공유(WebRTC)

### Phase 7 — 시스템/UX 완성
- [x] 토스트 알림·트레이·전역 단축키·테마·다중계정·Rich Presence

### Phase 8 — 최적화 & 배포
- [x] 목표 지표 대비 프로파일링·튜닝(메모리/기동/CPU/설치 크기)
- [x] per-user Inno Setup 패키징, DSA 서명 자동 업데이트

---

## 8. 리스크 & 대응

| 리스크 | 영향 | 대응 |
|--------|------|------|
| **ToS 위반/계정 정지** | 치명적 | 부계정 검증, 개인용 한정, 비공개 |
| 음성 프로토콜 리버스 난이도 | 일정 지연 | `discord.py`/`serenity` 등 오픈소스 구현 분석·포팅 |
| 비공식 API 변경 | 파손 | 스펙 모니터링, 버전 고정, 계층 격리로 국소 수정 |
| WebRTC 화면공유 복잡도 | 지연 | Phase 6 분리, PoC 선행 |
| Flutter 데스크톱 생태계 공백 | 구현 공수↑ | FFI/Win32 직접 연동, 필요한 플러그인 자체 작성 |
| 성능 목표 미달 | 대체 명분 약화 | 단계마다 벤치 게이트, Isolate·가상화 적극 적용 |

---

## 9. 마일스톤

1. **M1** 로그인 → Gateway READY → 서버/채널 표시 (P0~2)
2. **M2** 텍스트 메시징 완전 동작 (P3)
3. **M3** DM·친구 (P4)
4. **M4** 음성 통화 (P5)
5. **M5** 화상·화면공유 (P6)
6. **M6** 시스템 UX + 최적화 + 배포 (P7~8)

---

## 10. 완료 기준

1. `flutter analyze`, 전체 테스트와 80% line coverage gate 통과.
2. Windows Release build와 성능 4개 지표 gate 통과.
3. per-user installer, checksum, DSA signature와 HTTPS appcast 생성 검증.
4. 운영 key·feed와 실계정 장시간 검증은 저장소 밖 운영 절차 및 [[Open Questions]]로 추적.
