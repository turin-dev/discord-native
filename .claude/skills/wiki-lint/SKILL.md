---
name: wiki-lint
description: 위키 링크와 허브 건강도를 점검하고 후속 수정 스킬로 라우팅하는 진단 스킬. 위키 커밋/푸시 직전, 여러 문서나 허브를 건드린 뒤, 구조 이상이 의심될 때 unresolved links, orphan notes, deadends, 허브 누락, stale 설명 징후를 점검할 때 사용한다.
---

# Wiki Lint

## Overview

- 이 스킬은 직접 고치기보다 먼저 점검하고 분류하는 역할을 맡는다.
- 마감 품질 게이트처럼 위키의 건강도를 확인한다.
- 점검 기준을 잡기 전에 `루트의 AGENTS.md`를 읽고, 이 저장소에서 의도된 허브/링크/frontmatter 규칙이 무엇인지 다시 확인한다.
- 발견한 문제는 `wiki-sync`, `wiki-repair`, `wiki-expand` 중 맞는 곳으로 보낸다.

## When to Run

- 위키를 커밋하거나 푸시하기 직전
- 여러 문서나 허브를 한꺼번에 건드린 뒤
- 링크, 허브, 탐색 구조가 이상하다고 느껴질 때

## Checks

- unresolved links
- orphan notes
- deadends
- 새 문서 생성 뒤 허브 연결 누락
- stale 설명, 중복 설명, 충돌 설명의 징후
- `_Index`, `Glossary`, `Open Questions`, `Change Log` 동반 갱신 누락 가능성

의도된 예외 문서가 있다면 그 이유를 알고 점검한다.

## Routing After Findings

- 현재 작업 반영 누락이면 `wiki-sync`
- 잘못되거나 충돌하거나 깨진 구조면 `wiki-repair`
- 기존 구조에 자리가 없어서 생긴 문제면 `wiki-expand`

문제를 찾았는데도 어디에도 넘기지 않고 끝내지 않는다.

## Exit / Verification

- 필요한 점검을 실제로 돌렸다.
- 찾은 문제를 후속 스킬로 분류했거나 바로 같은 wave 안에서 고쳤다.
- 커밋/푸시 전에 알고 있는 구조적 문제를 조용히 남기지 않았다.
