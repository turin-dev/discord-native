---
name: wiki-expand
description: 기존 위키 구조에 자리가 없을 때 새 문서와 허브 구조를 열고 연결하는 스킬. 새 영역, 새 문서 묶음, 새 `_Index`, 새 탐색 진입점이 필요할 때 사용한다. 기존 문서를 억지로 늘리는 대신 구조를 확장해야 하는 경우에만 사용한다.
---

# Wiki Expand

## Overview

- 이 스킬은 새 문서를 만드는 것만으로 끝나지 않는다.
- 새 문서가 들어갈 구조, 허브, 진입점을 함께 열어 위키를 확장한다.
- 시작 전에 `루트의 AGENTS.md`를 읽고 새 core note와 허브가 따라야 할 규칙을 다시 맞춘다.
- 기존 구조 안에서 해결할 수 있으면 `wiki-sync`를 우선한다.

## When to Expand

- 기존 위키 구조 안에 이 내용을 담을 적절한 자리가 없다.
- 새 앱/패키지/흐름/계약/런북 묶음처럼 독립된 문서 세트가 필요하다.
- 기존 문서 하나에 억지로 넣으면 경계가 흐려지거나 탐색성이 무너진다.
- 최상위 진입 구조가 실제로 바뀌어서 `Home`까지 만져야 한다.

## Expansion Moves

- 필요한 새 문서를 만든다.
- 완전히 새로운 최상위 영역을 파기 전에, 가장 가까운 기존 상위 허브 안에서 새 구조를 열 수 있는지 먼저 본다.
- 문서 이름과 위치를 현재 위키 구조에 맞춘다.
- 새 core note에는 `루트의 AGENTS.md`가 권장하는 YAML frontmatter를 가능한 한 바로 붙인다.
  - `type`
  - `status`
  - `tags`
  - `source_paths`
  - `reviewed_at`
  - `confidence`
  - `aliases`
- 관련 문서끼리 `[[위키링크]]`를 연결한다.
- 이후 `wiki-sync`가 세부 내용을 채우기 쉬운 뼈대를 남긴다.

## Hub Updates

- 가장 가까운 `_Index`는 반드시 같이 갱신한다.
- 상위 허브가 바뀌면 부모 허브도 같이 갱신한다.
- 최상위 진입점이 달라지면 `Home`을 갱신한다.
- 필요하면 `Glossary`, `Open Questions`, `Change Log`도 같이 본다.

## Boundary Rules

- `wiki-sync`는 기존 노트 갱신이다.
- `wiki-repair`는 잘못된 기존 구조 복구다.
- `wiki-expand`는 새 자리와 새 연결을 여는 일이다.
- 기존 문서를 고치기 귀찮다는 이유로 `wiki-expand`를 쓰지 않는다.

## Exit / Verification

- 새 문서가 적절한 허브에 연결됐다.
- 필요할 때 `Home`까지 반영됐다.
- 새 문서가 고아 노트나 막다른 노트로 남지 않았다.
- 이후 `wiki-sync`가 내용을 채우기 쉬운 구조가 됐다.
