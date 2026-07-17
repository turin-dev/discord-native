# Security Policy

## 지원 범위

보안 수정은 기본적으로 최신 `main`을 대상으로 합니다. 아직 안정 release가 없으므로 과거 commit이나 비공식 binary는 지원하지 않습니다.

## 비공개 신고

GitHub 저장소의 **Security → Report a vulnerability**에서 private vulnerability report를 작성해 주세요. 공개 issue, discussion, pull request에 exploit, 사용자 토큰, 계정 정보 또는 개인 로그를 게시하지 마세요.

다음을 포함하면 재현과 대응에 도움이 됩니다.

- 영향받는 commit과 Windows/Flutter 버전
- 최소 재현 절차와 예상 영향
- 민감정보를 제거한 로그 또는 proof of concept
- 제안 완화책이 있다면 그 설명

접수 후 가능한 한 7일 안에 초기 확인하고, 수정과 공개 시점은 신고자와 조율합니다.

## 토큰과 운영 비밀값

Discord token은 앱의 OS secure storage에만 보관해야 합니다. 저장소는 `.env`를 자동으로 읽지 않으며, update feed와 DSA private key는 GitHub Actions secrets 또는 별도 보안 저장소로 주입해야 합니다. 비밀값이 Git 이력에 들어갔다면 삭제만 하지 말고 즉시 폐기·재발급한 뒤 private report로 알려 주세요.
