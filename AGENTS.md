# Runstir

프로필: 1인

재현 가능한 모바일 개발 런타임(`mobile` CLI와 macOS GUI). North Star: `git clone → mobile up`.
현재 상태: iOS React Native MVP 구현. 비공개 iOS internal-alpha는 [issue #83](https://github.com/minjunkim-labs/mobile-runtime/issues/83)이 정하고, 닫힌 [decision map #79](https://github.com/minjunkim-labs/mobile-runtime/issues/79)를 잇는다. [MVP 맵 #1](https://github.com/minjunkim-labs/mobile-runtime/issues/1)은 닫힌 과거 기록이다. 현재 결정은 `CONTEXT.md`와 `docs/adr/`에 있다.

## 명령

모든 에이전트와 사람이 같은 명령을 쓴다. `python3 -I .baseline/baseline.py run test`처럼 부른다. 이 칸은 `.baseline/commands.json`과 같아야 한다. 없는 칸은 `N/A: <이유>`다.

- setup: `swift package resolve --force-resolved-versions`
- check: `sh -c 'python3 -B -m unittest discover -s scripts/source-only -p "test_*.py" && python3 -B scripts/test-release-input.py'`
- test: `swift test --force-resolved-versions -Xswiftc -warnings-as-errors`
- build: `swift build --force-resolved-versions -Xswiftc -warnings-as-errors`

CI 전체(`.github/workflows/ci.yml`)는 위에 더해 actionlint·shellcheck, `scripts/verify-*-input.py`, release 패키지 검증, Linux Core 컴파일을 돌린다.

## 길잡이

| 경로 | 무엇 |
| --- | --- |
| `Sources/` | Core(플랫폼 독립), EnvironmentKit(CLI·GUI 공통 판단), SimulatorKit·AndroidKit, `mobile` CLI, RunstirGUI |
| `Tests/` | Swift 테스트와 fixture |
| `scripts/` | 패키징·검증 스크립트. `scripts/source-only/`는 합성 테스트 |
| `CONTEXT.md`, `docs/adr/` | 도메인 용어와 결정. [도메인 읽기](docs/agents/domain.md) |
| `docs/agents/` | [개발 절차](docs/agents/development.md)(작업 진입), [리뷰 절차](docs/agents/review.md)(CI·병합), [이슈 추적](docs/agents/issue-tracker.md), [라벨](docs/agents/triage-labels.md) |
| `.mise.toml` | 툴체인 판. `run`이 이 판(Python)으로 돈다. Swift·Xcode는 mise 밖이다. CI는 `macos-26` runner image의 기본 Xcode, Linux Core 컴파일은 `ci.yml`이 digest로 고정한 `swift` Docker image를 쓴다. 로컬은 Xcode를 App Store나 developer.apple.com에서 설치한다 |
| `docs/REPOSITORY_SETUP.md` | GitHub 설정 기대값과 감사 방법 |
| `REVIEW.md` | 리뷰 기준. 리뷰할 때만 읽는다. 상세 규칙은 `docs/coding-standards.md` |

이 파일이 에이전트 공통 지침이다. `CLAUDE.md`는 이 파일을 불러오는 `@AGENTS.md` 한 줄이다. 도구별 지침은 그 밖에 두지 않는다. 이슈는 GitHub Issues(`minjunkim-labs/mobile-runtime`)를 `gh`로 다룬다.

- 비밀값 규칙의 예외: `.env.example`은 읽고 커밋해도 된다.

## 병합

- 상시 지시: 문서·쉬움 PR은 리뷰가 끝나면 `python3 -I .baseline/baseline.py enqueue <PR> <리뷰한 head>`로 머지 큐에 넣는다. 소유자가 끄려면 이 줄을 지운다.

<!-- baseline:start -->
## 작업 방식

- 규칙은 repo-baseline의 [POLICY.md](https://github.com/minjunkim-labs/repo-baseline/blob/main/POLICY.md)다. 이 블록은 그 요약이다.
- 시작 전에 열린 PR과 Issue에서 같은 일을 찾는다. 있으면 그 PR을 잇거나 소유자에게 묻는다.
- 시작 전에 완료 기준을 정해 PR 본문 Summary에 쓴다. 완료 주장은 명령의 실제 출력이다.
- 리뷰 등급은 셋이다. 문서는 필수 CI만, 쉬움은 구현 대화를 물려받지 않는 하위 에이전트 리뷰 한 번, 어려움은 구현 대화를 물려받지 않는 새 세션 하나가 Spec·Standards와 보안 관점을 본 뒤 소유자 병합이다(POLICY §3).
- 등급은 `review-preflight`가 정하고 리뷰어는 올릴 수만 있다. `enqueue`는 어려움 PR을 넣지 않는다.
- 하위 에이전트·새 세션·headless 실행을 띄울 때는 POLICY §3의 모델 층과 effort를 사용자 전역 지시가 가리키는 층 표로 실제 모델로 바꾼다. 층은 내리지 않는다.
- 무엇을 만들고 무엇이라 부를지 정할 일이 크면 사람만 부르는 스킬(`grill-with-docs`, `wayfinder`, `to-spec`, `to-tickets`)의 이름을 대고 실행을 권한다.
- 이 블록은 repo-baseline이 관리한다. 고치지 않는다. 블록 밖은 프로젝트가 쓴다.

## 하지 않는 것

- 비밀값(`.env*`, 키, 토큰)을 읽거나 커밋하지 않는다. 커밋됐으면 먼저 키를 폐기한다.
- `main`에 직접 push하지 않는다. `enqueue`를 거치지 않고 병합하지 않는다.
- 어려움 PR(예: 돈, 인증·권한, 복구가 어려운 migration, workflow 권한, 에이전트 설정 폴더, `.baseline/`)을 병합하지 않는다.
- 우선순위·일정·내부 판단과 취약점 설명을 공개 Issue·PR·커밋에 쓰지 않는다.
- 브랜치 보호·저장소 설정·CI workflow를 사람 승인 없이 바꾸지 않는다.
<!-- baseline:end -->
