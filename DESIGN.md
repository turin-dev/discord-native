# Discord Native UI contract

Discord Native는 Discord 데스크톱의 정보 구조와 조작 밀도를 따르는 비공식 클라이언트다. 화면은 장식보다 대화 탐색 속도를 우선하며, 기능을 큰 카드로 분리하지 않는다.

## Layout

| Surface | Size | Role |
| --- | ---: | --- |
| Title bar | 32px | 앱 식별자, 전역 검색, 전역 도구 |
| Guild rail | 72px | DM과 guild 전환 |
| Channel sidebar | 240px | guild header, channel tree, user controls |
| Channel header | 48px | channel identity, topic, thread controls |
| Right panel | 240px | guild members, search, DM relationships |
| User panel | 52px | identity, connection, mute, deafen, settings |

메시지 영역은 남은 폭을 모두 사용한다. 메시지는 최신 항목이 composer 바로 위에 오도록 아래에서부터 쌓인다. 창 폭이 부족할 때 중앙 대화 영역이 먼저 줄어들며, 고정 rail과 sidebar의 폭은 바꾸지 않는다.

## Color

- `window`: 최상단 chrome과 가장 깊은 배경
- `guildRail`: guild navigation 배경
- `sidebar`: channel과 member panel 배경
- `chat`: 대화 배경
- `input`: composer와 검색 입력 배경
- `hover`, `selected`: 탐색과 메시지의 일시·지속 상태
- `brand`: primary action과 선택 guild
- `danger`, `warning`, `positive`: 삭제, 주의, 연결 상태

색상 원본은 `design-tokens.json`, Flutter 구현은 `discord_design_tokens.dart`를 단일 기준으로 사용한다.

## Typography

Windows 기본 환경에서는 `Segoe UI`를 사용한다. 본문은 14px, channel label은 15px, 보조 정보는 11–12px다. 중요한 계층은 크기보다 weight와 색상 대비로 구분한다.

## Interaction

- Guild는 48px 원형 icon이며 선택 시 radius가 줄고 왼쪽 흰색 indicator가 길어진다.
- Channel row는 34px다. 선택 상태는 고정 배경, unread는 굵은 label과 badge로 표현한다.
- Message action은 hover에서만 보이되, 메뉴가 열린 동안 anchor가 제거되지 않아야 한다.
- 검색 결과가 생기면 right panel은 자동으로 검색 tab으로 전환되고, 검색을 지우면 member tab으로 돌아간다.
- 사용자에게 영향을 주는 기능은 tooltip과 keyboard focus를 제공한다. 장식 icon은 action처럼 보이지 않게 한다.

## Reference preview

`design-preview.html`은 구현과 같은 32/72/240/48/240 shell과 핵심 상태를 정적으로 보여준다. 실제 동작 검증은 Flutter widget test와 Windows native build에서 수행한다.

Discord는 Discord Inc.의 상표다. 이 문서는 UI 호환 목표를 설명하며 공식 제품 또는 제휴를 의미하지 않는다.
