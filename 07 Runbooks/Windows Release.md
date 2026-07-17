---
type: runbook
status: active
tags: [windows, release, performance, installer, updater]
source_paths: [.github/workflows/windows.yml, packaging/discord_native.iss, tool/benchmark_windows.ps1, tool/package_windows.ps1, tool/sign_windows_update.ps1, tool/subset_material_icons.ps1]
reviewed_at: 2026-07-17
confidence: high
aliases: [Windows Release]
---

# Windows Release

## 품질 게이트

```powershell
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --minimum=80
flutter build windows --release --split-debug-info=build/symbols/windows
.\tool\subset_material_icons.ps1
.\tool\benchmark_windows.ps1 -Enforce
```

benchmark 기준은 시작 1.5초 미만, working set 200MB 미만, 유휴 CPU 0.5% 미만, 설치 디렉터리 60MB 미만이다. 2026-07-17 Release gate 결과는 각각 0.200초, 99.60MB, 0%, 59.05MB다. GitHub-hosted runner는 기동 편차가 있으므로 CI에서는 측정값을 artifact로 남기고 로컬 release gate에서 `-Enforce`를 사용한다.

## 오픈소스 공개 게이트

공개 push 전에는 프로젝트 루트에서 최신 gitleaks로 working tree와 전체 Git 이력을 모두 검사한다. `.gitleaks.toml` allowlist는 직접 검토한 vendored parser marker와 고정 test vector만 허용한다.

```powershell
gitleaks dir . --config .gitleaks.toml --redact --no-banner
gitleaks git . --config .gitleaks.toml --redact --no-banner
git diff --check
```

`third_party/mbedtls/framework/data_files/`는 Windows build가 `ENABLE_TESTING=OFF`, `ENABLE_PROGRAMS=OFF`로 사용하지 않는 upstream private-key test fixture이므로 공개판에서 제외한다. `LICENSE`, `THIRD_PARTY_NOTICES.md`, vendored dependency의 원문 license와 `windows/libdave/licenses/`는 release source와 binary 고지에 유지한다.

공개 저장소는 `https://github.com/turin-dev/discord-native`다. 일반 사용자 token 클라이언트의 Discord 약관 위험을 README와 `Open Questions.md`에서 계속 고지하고, 공식 client와의 절대적 feature parity를 주장하지 않는다.

## Installer

Inno Setup 6으로 per-user x64 installer를 만든다. release build를 이미 검증했다면 `-SkipBuild`를 사용할 수 있다.

```powershell
.\tool\package_windows.ps1 `
  -Version 1.0.0 `
  -BuildNumber 1 `
  -SkipBuild `
  -UpdateFeedUrl https://updates.example.com/appcast.xml
```

산출물은 `dist/discord-native-<version>-windows-x64-setup.exe`와 SHA-256 파일이다. 검증된 1.0.0 installer는 20,895,775 bytes다.

## 서명 업데이트

운영 build에는 WinSparkle DSA public key를 runner resource로 포함하고 private key는 build 머신에 저장하지 않는다. installer 생성 뒤 별도 서명 단계에서 HTTPS download URL을 사용해 appcast를 만든다.

```powershell
.\tool\sign_windows_update.ps1 `
  -InstallerPath .\dist\discord-native-1.0.0-windows-x64-setup.exe `
  -PrivateKeyPath $env:RUNNER_TEMP\dsa_priv.pem `
  -Version 1.0.0 `
  -DownloadUrl https://updates.example.com/discord-native-1.0.0-windows-x64-setup.exe
```

CI tag build에는 `DISCORD_NATIVE_UPDATE_FEED`, `WINSPARKLE_DSA_PUBLIC_KEY`, `WINSPARKLE_DSA_PRIVATE_KEY` secret이 모두 필요하다. private key 임시 파일은 `finally`에서 삭제하며 `dist/`와 key 파일은 Git에서 제외한다.

관련 문서: [[Windows Development]], [[Desktop System Integration]], [[Native Client Architecture]]
