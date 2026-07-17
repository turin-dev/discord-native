# Validation Recipes

## 원칙

- 이 패밀리는 문서를 쓰고 끝내지 않는다.
- 실제로 다른 에이전트가 스킬을 따라 원하는 동작을 하는지 반복 검증한다.
- 원하는 결과가 나오지 않으면 수정하고 다시 검증한다.

## 실험 환경

- 가능하면 원본 저장소를 직접 쓰지 말고 복사본이나 격리 작업 환경을 만든다.
- 위키 검증은 `루트의 `와 루트 `AGENTS.md`를 함께 복사한 환경에서 수행한다.
- 이전 실험 결과가 다음 검증에 누출되지 않게, 반복마다 작업 산출물을 정리한다.
- Windows에서 `quick_validate.py`를 다시 돌릴 때는 UTF-8을 강제한다.
  - 예: `uv run --with pyyaml python` 실행 전에 `PYTHONUTF8=1`을 준다.

## Subagent 검증

- `fork_context=false`인 subagent를 우선 쓴다.
- subagent에게는 스킬 경로와 작업 요청만 준다.
- 의도한 정답, 내가 기대하는 수정 방향, 실패 원인을 먼저 주지 않는다.
- 예시:
  - `Use $wiki-query at <path> before updating the onboarding flow docs for the dash app.`
  - `Use $wiki-first-engineering at <path> while implementing and documenting a settings flow change.`

## 반복 루프

1. 스킬 초안 작성
2. 격리 환경 준비
3. subagent forward-test 실행
4. 결과와 diff 검토
5. 스킬 수정
6. 환경 정리 후 새 subagent로 재검증
7. 원하는 동작이 안정적으로 나올 때까지 반복

## 합격 기준

- `wiki-first-engineering`을 썼을 때 시작과 종료에서 위키 루프가 실제로 적용된다.
- `wiki-query`가 코드 대신 위키 허브를 먼저 따라간다.
- `wiki-sync`가 기존 노트를 실제로 고친다.
- `wiki-repair`가 부족함이 아니라 잘못됨을 복구한다.
- `wiki-expand`가 새 문서와 허브를 함께 연다.
- `wiki-lint`가 문제를 찾아 적절한 후속 스킬로 분류한다.
- 새로 만들어진 core note가 있으면 `루트의 AGENTS.md`의 frontmatter 규칙을 대체로 따른다.
