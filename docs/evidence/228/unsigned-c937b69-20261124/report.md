alpha.18로 네이티브 Android 최소 앱 Todo와 OSS 앱 Now in Android(NIA)를 CLI 경로에서 다시 실행해 올바른 첫 화면과 정상 종료를 확인했습니다. #414(취소 때 그룹을 벗어난 후손 종료)는 Gradle 중 취소에서 남은 자식이 없음을 확인했습니다. #415(AVD 이름을 읽지 못하는 Emulator 건너뛰기)는 실제 Emulator에서 처음 확인했고, 그 경로에서 active-run 정리 결함을 새로 찾아 AC03 Todo를 fail로 기록했습니다. GUI 경로는 GUI 조작 권한 요청이 거부되어 실행하지 않았습니다. 이 문서는 alpha.18 후보 고정(#224 범위)과 #228의 실제 실행을 한 묶음으로 기록합니다.

후보는 `7aae56ec7fe18255885a0168d7aca347c56514d281d5a54f288b8ef7db37e3da`, 제품 source는 main `c937b694cfde4f0eeb0453ddc41ecb7f59f6b090`입니다. 이 SHA의 CI·CodeQL push run과 merge queue CI run은 첫 시도에서 모든 job이 성공했습니다. `scripts/package-release.sh` 한 번으로 CLI·GUI를 만들었고 archive smoke와 `scripts/verify-candidate.sh`가 통과했습니다. CLI·GUI가 같은 버전 `0.1.0-alpha.18`을 보고하고 공통 metadata·resource bytes가 같으며 GUI bundle에 CLI가 없습니다. alpha.17 이후 들어간 제품 PR은 #384·#405·#406·#414·#415이며 각 본문의 리뷰 기록을 제한 원본 `source-prs`에 보존했습니다. signing=unsigned, notarization=not-requested, distributionReady=false입니다.

## 입력을 새로 만든 이유

alpha.17까지 재사용한 고정 입력 24개(clone·JDK·SDK·Gradle cache·AVD)와 그 출처 기록이 2026-11-24에 디스크에 없었습니다. 그래서 #224의 입력 재감사를 할 수 없었고, 네이티브 Android 입력만 소유자 승인으로 새로 만들었습니다. Todo `ee66e152`와 NIA `a49ed253`를 upstream에서 받아 경로마다 별도 full clone 4개를 만들었습니다. SDK는 호스트 SDK 패키지를 복사한 소유 SDK이고, 라이선스 기록은 alpha.17이 재사용한 기록과 SHA-256이 같습니다(새 동의 없음). JDK는 Zulu 17.0.19·21.0.12.1 복사본이고, AVD `Runstir228_cli35`·`Runstir228_gui35`는 API35 Google APIs arm64 r9 image로 새로 만들었습니다. Gradle user home은 비어 있는 상태(cold Gradle cache)에서 시작했습니다. Emulator는 37.3.10으로 alpha.17의 37.1.11과 다릅니다. 따라서 AC15 후보·입력 연결은 네이티브 Android 범위만 되고, 나머지 tuple은 unverified입니다. 실행 전 조건은 `requirements-before-execution`에 먼저 기록했습니다.

수집 오류 하나를 고쳤습니다. 복사한 JDK의 `Contents/Home`이 원래 설치를 가리키는 절대 symlink라서 Todo의 처음 몇 단계(wrapper 사람 단계와 doctor·setup 계획 두 번)가 같은 버전의 원래 JDK로 돌았습니다. 상대 symlink로 고친 뒤의 단계는 소유 복사본을 썼습니다. 이 사실은 `input-set`에 남겼습니다.

## 결과

| 앱 | CLI | GUI | 준비 |
| --- | --- | --- | --- |
| Todo `:app/debug` | "You have no tasks!" 첫 화면, down이 앱 중지·claim 해제, 5초간 PID 부재 | 미실행 | cold cache에서 wrapper·Gradle 입력 사람 단계 안내 → 승인 → build 144.8초 |
| NIA `:app/demoDebug` | 알림 권한 대화상자를 UI에서 거부한 뒤 관심 주제 첫 화면, down이 앱 중지·claim 해제, 5초간 PID 부재 | 미실행 | 같은 사람 단계 뒤 기본 doctor는 모듈 둘로 warning, `--module :app --variant demoDebug`로 승인 → build 170.3초 |

**cold Gradle cache.** doctor는 고정 wrapper 배포본이 없다고 warning을 내고 직접 받지 않은 채 `gradlew --version` 실행을 안내했습니다. 다음 doctor는 오프라인 Gradle model이 없다며 `gradlew help` 실행를 안내했습니다. 수집기가 두 단계를 입력 env로 실행한 뒤 doctor가 wrapper·JDK·target·호환성·SDK·가속을 pass로 냈습니다. Todo의 ABI는 빌드 전이라 unknown이었습니다(alpha.13과 같음).

**#415와 새 결함.** 입력 HOME에 Emulator console 인증 사본을 만들기 전에 Todo `up`을 실행했습니다. `up`은 AVD 이름을 읽지 못한 Emulator를 건너뛰고 AVD를 직접 켜려 했습니다. 하지만 launcher가 같은 AVD 중복 실행으로 바로 종료되어 실패했고, 오류는 이름을 읽지 못한 Emulator 목록을 밝혔습니다. 여기까지는 #415의 의도와 맞습니다. 그런데 이 실패 뒤 active-run 기록에 serial 없이 launcher PID만 남았습니다. `down`은 매번 `android.emulator` unknown으로 기록을 보존했고, 같은 프로젝트의 `up`은 "incomplete Emulator identity"로 거부되며 다시 `down`을 안내했습니다. 같은 `up`이 남긴 기기 reservation은 다른 프로젝트(NIA)의 `up`도 거부했고, 그 안내는 거부되는 Todo `up`을 가리켰습니다. 그 AVD를 Runstir로 어느 프로젝트도 쓸 수 없게 된 것입니다. 소유자 승인으로 수집기가 byte가 같은 사본을 보존한 뒤 active-run 기록과 claim을 지웠고, 그 뒤 `up`·`down`이 통과했습니다. 제품 코드는 바꾸지 않았습니다. 이 결함은 별도 이슈로 다룹니다.

**#414 취소.** NIA `up`의 Gradle 단계 중 SIGINT는 130으로 0.03초 안에 끝났고, 신호 때 자식 java 2개가 모두 사라졌습니다. 이전 사람 단계가 남긴 Gradle daemon 3개와 수집기가 켠 adb server는 그대로였습니다. claim이 남지 않았고 바로 뒤 같은 AVD에서 다른 프로젝트(Todo)의 `up`·`down`이 통과했습니다. adb server가 취소된 명령의 자식인 경우는 이번에 만들지 않았습니다.

**GUI 미실행.** GUI clone 둘과 입력을 만들고 Runstir.app을 Todo 입력으로 띄웠습니다. GUI 조작 권한 요청이 거부되어 아무 조작 없이 종료했습니다. 따라서 GUI의 Todo·NIA 첫 화면(AC05 GUI 2개), 같은 입력의 CLI·GUI 비교(AC04 2개), GUI build 뒤 기기 칸 유지(#353)와 GUI 작업 취소 안내(#358)는 alpha.18에서 확인하지 않았습니다.

소유 AVD는 수집기가 `-no-window`로 먼저 켰으므로 제품 cold boot 증거가 아닙니다. AC06은 실제 Mac의 HVF 가속과 반복 up·down으로 확인했고, 보존 기준 VM은 실행하지 않았습니다. Android 실기기는 미검증입니다(AC19). 정리 뒤 소유 Emulator·Gradle daemon·adb server·claim이 남지 않았고, 콘솔 인증 사본은 지웠습니다.

## 판정

현재 결과는 pass 6개, fail 1개, unverified 44개입니다. pass는 AC05 CLI 2개, AC02 2개, AC03 NIA, AC06입니다. fail은 AC03 Todo(위 결함)입니다. AC15는 네이티브 Android 밖의 입력을 연결하지 못해 unverified입니다. AC17의 실패 이력 보존은 이번 묶음 안의 시도 기록으로 유지했습니다. alpha.17 결과는 다른 후보이므로 이 묶음에 승계하지 않았고, 저장소의 alpha.17 #228 증거에 그대로 남아 있습니다. 남은 미검증은 GUI 4개 행과 #353·#358, 빈 SDK root 준비 재실행, 같은 SDK root 동시 승인, 잘못된 variant·module 재실행, 원래 도구 기준선, 보존 기준 VM, Android 실기기(AC19), 다른 프레임워크와 공동 게이트입니다. unsigned 배포 제한도 있어 공동 출시 판정은 blocked입니다.
