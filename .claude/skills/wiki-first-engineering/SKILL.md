---
name: wiki-first-engineering
description: 코드 변경 작업 전반에서 위키를 1차 진입점으로 강제하고, 시작 전 `wiki-query`, 종료 전 `wiki-sync`, 위키-코드 충돌 시 `wiki-repair`, 새 구조 필요 시 `wiki-expand`, 마감 점검 시 `wiki-lint`로 라우팅하는 메타 스킬. 이 저장소에서 기능 추가, 버그 수정, 리팩터링, 구조 변경, 코드와 결합된 문서 작업을 수행할 때 사용한다.
---

# Wiki First Engineering

## Trigger

- 코드 변경이 들어가는 작업이면 기본적으로 이 스킬 루프를 적용한다.
- 사용자가 위키 갱신을 명시적으로 금지하지 않았다면, 위키 참조와 위키 동기화를 기본 규칙으로 본다.
- 위키를 코드보다 먼저 읽는 것을 기본값으로 두고, 코드 탐색은 위키가 부족한 지점에만 쓴다.
- 위키를 만지는 순간 `루트의 AGENTS.md`를 이 레포의 위키 운영 규칙으로 다시 읽는다.
- 세부 라우팅이 필요하면 [routing-table.md](routing-table.md)를 본다.

## Start Gate

1. 이번 작업에서 바뀔 가능성이 큰 위키 축을 먼저 잡는다.
   - `Architecture`
   - `Modules`
   - `Flows`
   - `Contracts`
   - `Decisions`
   - `Runbooks`
   - `Glossary`
   - `Open Questions`
2. 현재 스레드에 관련 위키 문맥이 없거나 낡았을 수 있으면 `wiki-query`를 먼저 탄다.
3. 같은 스레드에서 방금 관련 위키를 충분히 읽었다면 전부 다시 읽지 말고, 필요한 노트만 짧게 다시 확인한다.
4. 관련 위키를 보지 않고 코드부터 뒤지지 않는다.
5. 위키를 편집할 예정이면 `루트의 AGENTS.md`를 한 번 더 읽고, frontmatter/링크/source-of-truth 규칙을 현재 작업에 맞춘다.
6. 위키를 읽는 과정에서 stale 설명, 충돌, 깨진 허브가 보이면 그 상태를 그대로 믿지 말고 `wiki-repair` 경로를 연다.

세부 시작/종료 게이트는 [completion-gates.md](completion-gates.md)에 정리한다.

## Routing Table

| 상황 | 사용할 스킬 |
| --- | --- |
| 작업 시작 전에 관련 위키를 찾고 읽어야 한다 | `wiki-query` |
| 코드 변경 후 기존 위키를 현재 상태에 맞춰야 한다 | `wiki-sync` |
| 위키와 코드가 어긋나거나, 위키끼리 충돌하거나, 허브/링크가 깨져 있다 | `wiki-repair` |
| 기존 위키 구조에 자리가 없어 새 문서/새 허브를 열어야 한다 | `wiki-expand` |
| 여러 문서/허브를 건드렸거나 커밋/푸시 직전 품질 점검이 필요하다 | `wiki-lint` |

자주 나오는 흐름 예시는 [workflow-recipes.md](workflow-recipes.md)에 둔다.

## Finish Gate

- 작업을 끝냈다고 말하기 전에 반드시 `wiki-sync` 판단을 거친다.
- 종료 결과는 아래 둘 중 하나여야 한다.
  - 관련 위키를 실제로 갱신했다.
  - 이번 변경은 위키 갱신이 불필요하다고 명시적으로 판단했다.
- 여러 문서나 허브를 건드렸다면 `wiki-lint`까지 돌려서 구조 점검을 마무리한다.
- 위키 구조 문제를 인지한 채로 조용히 종료하지 않는다.

반복 검증 루프는 [validation-recipes.md](validation-recipes.md)를 따른다.

## Red Flags

- 위키를 보지 않고 코드부터 탐색한다.
- stale하거나 충돌하는 위키를 그대로 사실로 취급한다.
- 기존 노트를 갱신할 수 있는데도 새 문서를 바로 만든다.
- `_Index`, `Glossary`, `Open Questions`, `Change Log` 같은 동반 갱신을 빼먹는다.
- `Home` 갱신을 `wiki-sync`가 자동으로 맡는다고 착각한다.
- `wiki-sync` 결과 없이 작업을 끝냈다고 선언한다.

## Exit / Verification

- 관련 위키를 작업 초반에 먼저 읽었다.
- 상황에 맞는 하위 스킬로 라우팅했다.
- 위키가 변경을 반영했거나, 반영 불필요 판단이 남아 있다.
- 여러 문서를 건드린 경우 필요 시 `wiki-lint`를 돌렸다.
- 구조적으로 깨진 상태를 알고도 방치하지 않았다.
