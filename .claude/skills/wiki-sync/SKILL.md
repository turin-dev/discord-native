---
name: wiki-sync
description: 코드 변경 후 기존 위키 문서를 현재 구조와 동작에 맞게 갱신하는 수정 스킬. 기능 추가, 버그 수정, 리팩터링, 경계 이동, 계약/환경/배포 변화 뒤에 관련 위키와 동반 문서(`_Index`, `Glossary`, `Open Questions`, `Change Log`)를 맞출 때 사용한다. 새 문서가 필요하면 직접 확장하지 말고 `wiki-expand`와 함께 사용한다.
---

# Wiki Sync

## Overview

- 이 스킬의 중심은 판단보다 수정이다.
- 기본값은 기존 위키를 현재 코드와 설정에 맞게 고치는 것이다.
- 시작 전에 `루트의 AGENTS.md`를 읽고 이 저장소의 위키 운영 규칙을 다시 맞춘다.
- 정말로 건드릴 문서가 없을 때만 갱신 불필요 판단으로 끝낸다.
- 새 문서를 임의로 만들지 않는다. 기존 자리가 없으면 `wiki-expand`를 탄다.

## Quick Triage

- 이번 변경이 어느 위키 축에 닿는지 먼저 잡는다.
  - `Architecture`
  - `Modules`
  - `Flows`
  - `Contracts`
  - `Decisions`
  - `Runbooks`
  - `Glossary`
  - `Open Questions`
- 이미 이 내용을 설명하는 기존 노트가 어디인지 확인한다.
- 정말로 위키 영향이 없는 예외인지 짧게 확인한다.
- 기존 구조 안에 자리가 없으면 여기서 멈추고 `wiki-expand`를 호출한다.

## What to Update

- 가장 직접적인 기존 노트를 먼저 갱신한다.
- 코드에서 바뀐 책임, 흐름, 런타임 경계, 계약, 환경, 운영 포인트를 문서에 반영한다.
- 코드와 설정, 최신 위키, 관련 `docs/` 문서를 source of truth 순서로 확인한다.
- 구조적으로 의미 있는 설명을 우선하고, 파일 나열은 필요한 최소한만 남긴다.
- 확실하지 않은 내용은 단정하지 말고 `Open Questions`로 보낸다.

## Update Rules

- 기존 노트 갱신을 새 문서 생성보다 우선한다.
- `루트의 AGENTS.md`의 위키 운영 규칙을 따른다.
- core note를 건드리면 frontmatter도 같이 본다.
  - `source_paths`
  - `reviewed_at`
  - `confidence`
  - `tags`, `aliases`, `status`가 현재 역할과 맞는지
- 문서는 한국어 중심으로 쓴다.
- Obsidian `[[위키링크]]`를 사용한다.
- 중복 설명을 만들지 않는다.
- 코드 변경을 위키에 반영하되, 증거 없이 과장하거나 추정하지 않는다.
- `Home` 갱신이 필요하면 `wiki-expand` 쪽으로 넘긴다.

## Required Companion Updates

- 관련 `_Index`는 강하게 같이 본다.
- 새 용어, 용례 변화, 중요 모델 이름 변화가 있으면 `Glossary`를 같이 본다.
- 새 미확인 사항이 생기거나 기존 질문이 해소되면 `Open Questions`를 같이 본다.
- 여러 문서에 걸친 갱신, 구조 변화, 운영 규칙 변화, 배포 정책 변화가 있으면 `Change Log`를 같이 갱신한다.
- 단일 문서의 아주 작은 정정은 `Change Log`를 생략할 수 있다.
- `Home`은 `wiki-expand`가 맡는다고 가정한다.

## Exit / Verification

- 관련 기존 노트가 실제로 갱신되었거나, 갱신 불필요 판단이 명시돼 있다.
- 필요한 `_Index`, `Glossary`, `Open Questions`, `Change Log`를 함께 점검했다.
- 새 문서를 임의로 만들지 않았다.
- 여러 문서를 건드렸거나 커밋/푸시 직전이면 `wiki-lint` 필요성을 다시 봤다.
