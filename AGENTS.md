# Repository Guide

- 사용자와 문서는 한국어를 기본으로 하되 코드 식별자는 원문을 유지한다.
- 기능 변경은 wiki 문서를 먼저 확인하고 테스트를 먼저 작성한다.
- 기존 객체를 직접 수정하지 않고 새 객체를 만든다.
- `any`, production `console.log`, silent error handling, hard-coded secrets를 사용하지 않는다.
- Dart 변경 후 format, analyze, test, 80% coverage gate를 실행한다.
- Windows/native 변경 후 release build와 benchmark를 실행한다.
- 관련 wiki와 `Change Log.md`를 코드와 함께 갱신한다.
- commit은 Conventional Commits 형식을 사용한다.
