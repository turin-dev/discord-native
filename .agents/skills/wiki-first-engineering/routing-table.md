# Routing Table

## 기본 라우팅

| 작업 유형 | 기본 흐름 |
| --- | --- |
| 새 기능 추가 | `wiki-query` -> 구현 -> `wiki-sync` |
| 버그 수정 | `wiki-query` -> 디버깅/수정 -> `wiki-sync` |
| 리팩터링 | `wiki-query` -> 리팩터링 -> `wiki-sync` |
| 위키 설명과 코드 충돌 발견 | `wiki-query` 또는 현재 문맥 확인 -> `wiki-repair` |
| 기존 구조에 자리가 없는 새 영역 등장 | `wiki-query` -> `wiki-expand` -> 필요 시 `wiki-sync` |
| 위키 커밋/푸시 직전 점검 | 필요 시 `wiki-sync` -> `wiki-lint` |

## 빠른 분기 규칙

- 읽기와 진입점 찾기가 목적이면 `wiki-query`
- 현재 작업을 반영해 기존 노트를 고치려면 `wiki-sync`
- 틀린 설명, 충돌, 깨진 허브를 바로잡으려면 `wiki-repair`
- 새 문서와 새 허브를 열어야 하면 `wiki-expand`
- 건강도 점검과 후속 분류가 목적이면 `wiki-lint`
