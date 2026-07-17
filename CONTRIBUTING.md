# Contributing

기여를 환영합니다. 먼저 기존 issue를 검색하고, 큰 변경은 구현 전에 issue에서 범위와 공개 API 제약을 합의해 주세요.

## 개발 흐름

1. 저장소를 fork하고 짧은 feature branch를 만듭니다.
2. 실패하는 테스트를 먼저 추가합니다.
3. 기존 객체를 직접 수정하지 않고 새 객체를 생성합니다.
4. 사용자 입력과 외부 API 응답은 경계에서 검증하고 오류를 명시적으로 처리합니다.
5. 아래 품질 게이트를 통과한 뒤 pull request를 엽니다.

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --minimum=80
```

Windows native 또는 배포 경로를 수정했다면 release build도 실행해 주세요.

```powershell
flutter build windows --release --split-debug-info=build/symbols/windows
.\tool\subset_material_icons.ps1
.\tool\benchmark_windows.ps1 -Enforce
```

커밋은 `<type>: <설명>` 형식을 사용합니다. 허용 type은 `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`입니다.

## Pull request 기준

- 변경 이유와 사용자 영향을 설명합니다.
- 관련 테스트와 문서를 함께 갱신합니다.
- 사용자 토큰, API key, 로그, 개인 경로를 포함하지 않습니다.
- vendored dependency를 변경하면 upstream URL, 고정 버전, 수정 내용, 라이선스를 기록합니다.
- Discord 비공개 endpoint를 추가할 때 약관 위험과 실패 동작을 명시합니다.

Contributor가 제출한 기여는 해당 파일에 별도 고지가 없는 한 프로젝트의 MIT License로 제공됩니다.
