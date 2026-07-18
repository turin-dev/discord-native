# Discord Native UI contract

Discord Native는 Discord 데스크톱의 정보 구조와 조작 밀도를 따르는 비공식 클라이언트다. 화면은 장식보다 대화 탐색 속도를 우선하며, 기능을 큰 카드로 분리하지 않는다.

## Layout

| Surface | Size | Role |
| --- | ---: | --- |
| Title bar | 32px | 앱 식별자, 전역 검색, 전역 도구 |
| Guild rail | 72px | DM과 guild 전환 |
| Guild channel sidebar | 240px 기본, 220–360px | guild header, channel tree, user controls |
| Direct message sidebar | 320px | 대화 검색, 친구 바로가기, avatar·unread DM 목록 |
| Channel header | 48px | channel identity, topic, thread controls |
| Right panel | 240px | guild members, search, DM relationships |
| User panel | 52px | identity, connection, mute, deafen, settings |

메시지 영역은 남은 폭을 모두 사용한다. 메시지는 최신 항목이 composer 바로 위에 오도록 아래에서부터 쌓인다. 창 폭이 부족할 때 중앙 대화 영역이 먼저 줄어든다. guild channel sidebar는 오른쪽 handle로 220–360px 안에서 조절하고 설정에 저장한다. DM sidebar는 공식 데스크톱 정보 밀도에 맞춘 320px 고정 폭을 사용한다. 1:1 DM은 우측 participant panel을 닫고 group DM만 240px 멤버 panel을 표시한다.

## Color

- `window`: 최상단 chrome과 가장 깊은 배경
- `guildRail`: guild navigation 배경
- `sidebar`: channel과 member panel 배경
- `chat`: 대화 배경
- `input`: composer와 검색 입력 배경
- `hover`, `selected`: 탐색과 메시지의 일시·지속 상태
- `brand`: primary action과 선택 guild
- `danger`, `warning`, `positive`: 삭제, 주의, 연결 상태

Flutter 런타임은 `DiscordPalette`의 system/light/ash/dark/onyx palette를 사용한다. Windows system dark는 참조 화면에서 추출한 Midnight 계열 onyx palette를 기본으로 사용하며 사용자가 명시적으로 dark를 고르면 표준 dark palette를 적용한다. `design-tokens.json`은 기본 dark 교환 형식이며, 실제 테마별 값은 `discord_design_tokens.dart`가 기준이다.

## Typography

Windows 기본 환경에서는 `Segoe UI`를 사용한다. 본문은 14px, channel label은 15px, 보조 정보는 11–12px다. 중요한 계층은 크기보다 weight와 색상 대비로 구분한다.

## Interaction

- Guild는 48px 원형 icon이며 선택 시 radius가 줄고 왼쪽 흰색 indicator가 길어진다.
- Channel row는 34px다. 선택 상태는 고정 배경, unread는 굵은 label과 badge로 표현한다.
- DM row는 44px이며 1:1 avatar 또는 group fallback avatar, display name과 unread badge를 표시한다. DM header와 composer 문구에는 guild channel용 `#`를 붙이지 않는다.
- DM header의 검색 입력은 현재 private channel만 조회한다. 검색 중에는 1:1의 닫힌 우측 영역 또는 group DM 멤버 panel 자리에 240px 결과 panel을 열고, 결과 선택 시 해당 message 주변 대화로 이동한다.
- compact/default/spacious 설정은 guild rail, channel row와 user panel의 밀도를 함께 바꾼다.
- title bar의 뒤로·앞으로 버튼은 방문한 guild/channel 기록을 보존하고, Inbox는 현재 로컬 unread channel을 연다.
- channel context action으로 고정한 channel은 별도 상단 section에 표시되고 설정에 저장된다.
- Message action은 hover에서만 보이되, 메뉴가 열린 동안 anchor가 제거되지 않아야 한다.
- 검색 결과가 생기면 right panel은 자동으로 검색 surface로 전환되고, 검색을 지우면 guild member 또는 group DM member surface로 돌아간다.
- 사용자에게 영향을 주는 기능은 tooltip과 keyboard focus를 제공한다. 장식 icon은 action처럼 보이지 않게 한다.

## Reference preview

`design-preview.html`은 구현과 같은 32/72/320/48/240 DM shell과 핵심 상태를 정적으로 보여준다. 실제 동작 검증은 Flutter widget test와 Windows native build에서 수행한다.

Discord는 Discord Inc.의 상표다. 이 문서는 UI 호환 목표를 설명하며 공식 제품 또는 제휴를 의미하지 않는다.
