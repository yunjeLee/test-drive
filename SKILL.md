---
name: test-drive
description: Use when a change or a crash fix must be verified by actually driving
  an Android app on a device or emulator instead of by unit tests, including
  reproducing a crash to find its cause. E2E 테스트 해줘, 실기기로 테스트,
  에뮬레이터로 확인, 크래시 재현해줘, 앱 직접 돌려서 검증, /test-drive 요청 시.
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "bash ~/.claude/skills/test-drive/hooks/guard-bash.sh"
---

# test-drive

사람이 손으로 하던 Android E2E 를 agent 가 대신 돌린다.

실행 엔진은 하나다. 성공기준이 부호를 담아 두 용도를 처리한다 — 기능 검증(`FATAL 0건`)과 크래시 재현(`FATAL ≥1건`).

## 흐름

| 단계 | 하는 일 | 게이트 |
|---|---|---|
| 1 | 성격 판정 · 자료 요구 | 자료 제출 · 사용자 확인 |
| 2 | 기기 · 빌드 변형 선택 | 사용자 선택 |
| 3 | `scenario.md` 작성 | 사용자 검토 |
| 4 | 사전 탐색 · `run.sh` 생성 · 백그라운드 실행 | 사용자 확정 |
| 5 | `result.md` · `failures.md` · `summary.md` 작성 | — |

단계를 건너뛰지 않는다.

## 산출물 위치

```
.test-drive/DCL1538-온보딩/
├── scenario.md
├── run.sh
├── summary.md
├── failures.md
└── runs/
    └── 004_S02-S12_FAIL-1_중단@S10.3/
        ├── result.md · run.log · run.sh
        ├── fail/S08.4_check.png · S08.4_check.xml
        └── evidence/
```

| 대상 | 규칙 | 만드는 것 |
|---|---|---|
| 작업 폴더 | `<일감번호>-<요약>`. 일감번호가 없으면 `<YYYY-MM-DD>-<요약>` | agent |
| run 폴더 | 시작 시 `NNN_S<시작 2자리>-S<끝 2자리>` | `scripts/td-new-run.sh` |
| run 폴더 접미사 | 종료 후 `_<TD_SUFFIX>` 를 붙인다 | `scripts/td-finalize.sh` |
| `run.sh` 스냅샷 | 실행한 `run.sh` 를 run 폴더에 복사한다 | `td_require_env` |
| 실패 캡처 | `fail/<SID>_<종류>.png` · `.xml`. SID 는 `S%02d.<스텝>`, 종류는 `step` · `check`. 같은 이름이 있으면 `_2`, `_3` 을 붙인다 | `td_capture_failure` |
| 판정 근거 | `evidence/` | run.sh |
| `result.md` | run 1회의 실행 직후 판정 | `td-finalize.sh` 초안 → agent |
| `failures.md` | 작업 전체의 실패 목록 · 분류 | `td_capture_failure` 행 추가 → agent |
| `summary.md` | 시나리오별 최종 판정 · run 목록 | agent |

## 1. 성격 판정 · 자료 요구

두 칸으로 나뉜다. **1a 는 성격만 정한다. 시나리오의 근거는 1b 에서 받는다.**

### 1a. 성격 판정

근거를 순위대로 훑는다. 산출은 성격 하나다.

| 순위 | 근거 | 확인 방법 |
|---|---|---|
| ① | 현재 세션 맥락 | 이 대화에서 진행한 작업 |
| ② | 최근 작업 폴더 | `ls -t .test-drive/` |
| ③ | 하네스 산출물 | `.harness/runs/` · `.harness/handoffs/` 가 있을 때만 |
| ④ | git | 브랜치명 · `git status --short` · `git diff HEAD --stat` · `git log -5 --oneline` |

①②③ 중 하나라도 성격을 특정하면 거기서 멈추고 ④ 로 내려가지 않는다.

**근거 약함 — ④ 까지 내려왔을 때만 본다. 하나라도 걸리면 추론을 포기하고 성격을 사용자에게 묻는다.**

- `git diff HEAD` 가 0줄이고 현재 브랜치가 통합 브랜치(`main` · `master` · `develop` · `release`)다.
- 변경이 서로 다른 최상위 모듈 3개 이상에 걸쳐 있다.
- 최근 커밋 5개가 전부 병합 커밋이다.

추측은 여기서 끝난다. 성격은 1b 의 질문을 고르는 데만 쓴다.

### 1b. 자료 요구

성격에 맞는 자료를 사용자에게 요구한다. **추측으로 채우지 않는다.**

받는 형식은 넓게 열고, 판정은 **필수 항목이 다 찼는가** 하나로 한다. 빈 칸만 골라 묻는다.

#### 크래시 재현 — 받는 형식

| 받은 것 | 하는 일 |
|---|---|
| Crashlytics 이슈 URL · 이슈 ID | 현재 세션 툴 목록에 `crashlytics_get_issue` 가 있으면 조회한다. 없으면 식별자로만 기록하고 나머지를 묻는다 |
| 스택트레이스 붙여넣기 | 클래스 · 줄번호를 읽는다. 기기 · OS · 앱 버전은 담기지 않으므로 묻는다 |
| `edit-crash` Notion 페이지 URL | `notion-fetch` 로 읽는다. 원인 · 재현 · 기기/OS 가 이미 정리돼 있다 |

이슈 ID 는 16진수 UUID 다. Firebase 콘솔 이슈 URL 끝에 있다.

#### 크래시 재현 — 필수 항목

| 필수 | 쓰이는 곳 |
|---|---|
| 스택트레이스 — 클래스 · 줄번호 | 3단계 `기준:` 의 스택 매칭 |
| 발생 기기 · OS 버전 | 2단계 기기 · AVD 선택 |
| 앱 버전 | 2단계 빌드 변형 |

| 선택 | 없으면 |
|---|---|
| 알려진 재현 경로 | 3단계 스텝을 사용자와 함께 만든다 |

스택 심볼이 난독화돼 있으면(`a.b.c:12`) 그대로 `기준:` 에 쓴다. 2단계에서 **같은 mapping 의 release 빌드**를 고르지 않으면 매칭되지 않는다.

#### 기능 검증 — 필수 항목

| 필수 | 쓰이는 곳 |
|---|---|
| 기대 동작의 출처 | 3단계 `기준:` |
| 검증 범위 (화면 · 플로우) | 3단계 시나리오 분할 |

기대 동작의 출처는 **사람이 준 것이면 형식을 가리지 않는다** — 기획서·정책서 경로, Notion URL, 사용자가 채팅으로 불러준 문장.

---

차단하는 것은 agent 추측 하나다. **필수 항목이 다 차지 않으면 1단계에서 멈춘다. 시나리오를 쓰지 않는다.**

받은 자료를 정리해 보여주고 확인받는다. 확인 없이 2단계로 가지 않는다.

```
작업: <한 줄>
일감: <번호 | 없음>
성격: 기능 검증 | 크래시 재현
근거 자료: <출처> — <받은 내용 요약>
```

## 2. 기기 · 빌드 변형 선택

연결 기기와 AVD 를 한 목록으로 보여주고 고르게 한다.

```bash
ADB=$(ls "$HOME/Library/Android/sdk/platform-tools/adb" 2>/dev/null || command -v adb)
"$ADB" devices -l
"$HOME/Library/Android/sdk/emulator/emulator" -list-avds
```

AVD 를 고르면 `scripts/td-lib.sh` 의 `td_boot_wait` 로 띄우고 부팅 완료까지 기다린다.

고른 뒤 고정한다.

| 항목 | 값 |
|---|---|
| `ANDROID_SERIAL` | 선택한 serial. 기기가 2대 이상이면 필수다 |
| `ADB` | 절대경로. `adb` 는 PATH 에 없다 |
| `TD_PKG` | applicationId. `build.gradle` 또는 `adb shell pm list packages` 로 확인한다 |

빌드 변형을 같이 고른다. 아래 신호가 있으면 **release 를 권하고 이유를 말한다** — debug 는 난독화가 없어 재현되지 않는다.

- R8 · ProGuard · 난독화 · `mapping.txt`
- `Parcelable` · `Serializable` · `ClassNotFoundException` · `BadParcelableException`
- 리플렉션 · `Class.forName` · Gson/Moshi 의 타입 추론

빌드는 test-drive 가 한다. 시나리오가 두 빌드를 요구하면 둘 다 빌드한다.

### 설치본 서명 비교

빌드 후 기기의 설치본과 설치할 APK 의 서명을 비교한다.

```bash
TD_PKG=<applicationId> ANDROID_SERIAL=<serial> bash -c '
  source ~/.claude/skills/test-drive/scripts/td-lib.sh
  echo "설치본 $(td_installed_sig || echo 없음)"
  echo "빌드   $(td_apk_sig "<apk 경로>")"'
```

| 결과 | 다음 |
|---|---|
| 설치본 `없음` | 비교하지 않는다 |
| 두 값이 같다 | `install -r` 로 덮는다 |
| 두 값이 다르다 | uninstall 이 필요하다. 로그인 · 앱 데이터가 삭제된다고 알리고 실행 전에 확인받는다 |
| 설치본 값이 비었다 | base.apk pull 실패다. 서명 불명으로 보고하고 uninstall 여부를 묻는다 |

## 3. 시나리오 + 성공기준

### 코드 조사

`agents/code-research.md` 의 A1 템플릿을 채워 `Explore` 에이전트에 맡긴다. 결과 표로 스텝의 술어 · `기준:` · 사전 탐색 대상 화면을 정한다.

### scenario.md 작성

`references/scenario-format.md` 를 읽고 `scenario.md` 초안을 쓴다. 내용을 채팅에 보여준다. 사용자가 말로 고치면 파일에 반영하고 다시 보여준다.

### 스텝 종류

| 표기 | 실행 |
|---|---|
| `[auto]` | adb 명령 또는 uiautomator 좌표 탭 |
| `[human]` | `👉 사람:` 을 출력하고 감지 조건을 상한 없이 폴링한다 |
| `[human:chat]` | `[human]` 의 폴백. 감지 조건을 만들 수 없을 때만 쓴다. 판정에 쓰지 않는다 |
| `[check]` | 성공기준을 판정한다 |

### `[auto]` 가 최우선이다

`[human]` 은 agent 가 기기 조작으로 만들 수 없는 상태에만 쓴다.

| `[human]` 으로 뺀다 | `[auto]` 로 한다 |
|---|---|
| 외부 계정·서버 이벤트 (방송 켜기, 상대방 메시지) | 화면 탭 · 스크롤 · 텍스트 입력 |
| 실제 결제 | APK 설치 · 삭제 · 재설치 |
| SMS · OTP · 생체인증 | 권한 부여 · 회수 |
| 로그인 자격증명 입력 | 딥링크 · 인텐트 실행 |
| 서버 상태 변경 | task 제거 · 뒤로가기 · 앱 전환 · recents |

오른쪽 열을 `[human]` 으로 빼지 않는다.

### `[human]` 에는 감지 조건을 반드시 쓴다

감지 조건이 없는 `[human]` 은 시나리오 미완성이다. 조건은 기기 상태로 판정할 수 있어야 한다.

감지 조건을 만들 수 없으면 `[human:chat]` 으로 내리고 **왜 불가인지 한 줄을 적는다.** 이유 없는 `[human:chat]` 을 쓰지 않는다.

### 시나리오는 3부 고정이다

`사전조건 → 스텝 → 복구`. 사전조건이 안 맞으면 그 시나리오를 `실행불가` 로 기록하고 다음 시나리오로 간다. 복구는 실패했을 때도 실행한다.

앞 시나리오의 결과가 전제면 `의존: 시나리오 N` 을 쓴다. 의존 대상이 `PASS` · `건너뜀` 이 아니면 기기를 조작하지 않고 `실행불가` 로 기록한다.

### 성공기준은 부호를 담는다

| 용도 | 기준 예 |
|---|---|
| 기능 검증 | `FATAL 0건` · `topResumedActivity 가 HomeActivity` |
| 크래시 재현 | `FATAL ≥1건` · 스택에 `SplashActivity.kt:48` |
| 수정 검증 | `FATAL 0건` |

기능 검증 · 수정 검증 시나리오는 `FATAL 0건` 판정을 반드시 둔다. 형식은 `references/scenario-format.md` 의 규칙을 따른다.

판정 수단은 `references/adb-recipes.md` 에 있다.

## 4. 확정 및 실행

### 4a. 사전 탐색

필수다. 클린 설치 → 실행 → 메인 도달까지 화면마다 `td-probe.sh` 로 확인한다.

```bash
ANDROID_SERIAL=<serial> ~/.claude/skills/test-drive/scripts/td-probe.sh
```

- 출력의 `TOP` · `IDS` · `TEXT` · `CLICK` 으로 다음 조작을 정한다.
- 메인 앞을 가로막는 화면(권한 · 약관 · 업데이트 안내 · 온보딩) 중 검증 대상이 아닌 것을 시나리오 1 스텝에 넣는다.
- 술어는 `td-probe.sh "" "<술어>"` 로 기기 화면에서 매칭을 확인한 뒤 쓴다. 매칭이 없으면 `MATCH 없음` 과 exit 1 이다.
- 클린 설치를 위한 uninstall · `pm clear` 는 사용자 확인 후 한다.
- 바뀐 `scenario.md` 를 보여주고 확정받는다.

### 4b. run 생성 · 실행

`.test-drive/` 를 처음 만들 때 `.gitignore` 에 넣을지 한 번 묻는다.

`scenario.md` 에서 `run.sh` 를 생성한다. 생성 규칙은 `references/scenario-format.md` 에 있다.

run 폴더는 `td-new-run.sh` 로 만든다. 라벨을 묻지 않는다. 출력은 run 폴더의 절대경로 한 줄이다. Bash 도구는 셸 변수를 유지하지 않으므로 이후 호출에는 이 경로를 그대로 적는다.

**백그라운드로 실행한다.** `[human]` 폴링은 상한이 없어 Bash 도구의 10분 제한에 걸린다. 포그라운드 `bash run.sh` 는 hook 이 차단한다.

```bash
RUN=$(~/.claude/skills/test-drive/scripts/td-new-run.sh <작업폴더> <시작번호> <끝번호>)
cd <작업폴더> && TD_RUN_DIR="$RUN" bash run.sh > "$RUN/run.log" 2>&1   # run_in_background: true
```

로그를 tail 해 진행을 따라간다.

- `👉 사람:` 이 뜨면 **채팅으로도 알린다.** 사용자가 터미널을 보고 있지 않을 수 있다.
- `👉 사람(채팅):` 이 뜨면 사용자에게 묻고, 확인을 받은 뒤 `touch <run 폴더>/<마커>.ok` 로 스크립트를 재개시킨다.

| 상황 | 할 일 |
|---|---|
| 중단 | `pkill -f "bash run.sh"`. 백그라운드 프로세스 · 포트 포워딩 정리는 trap 이 한다. 이 명령은 모든 run 을 멈추므로 run 은 한 번에 하나만 실행한다 |
| 실행 중 수정 | 하지 않는다. bash 는 실행 중에 파일을 이어 읽는다. 고칠 일이 생기면 중단 후 고친다 |
| 재실행 | `scenario.md` 를 고치고 `run.sh` 를 다시 생성한 뒤 `td-new-run.sh` 로 새 run 을 만든다. 이어서 할 시나리오 번호를 `TD_START_FROM` 으로 넘긴다 |

```bash
RUN=$(~/.claude/skills/test-drive/scripts/td-new-run.sh <작업폴더> <이어서 할 번호> <끝번호>)
cd <작업폴더> && TD_START_FROM=<이어서 할 번호> TD_RUN_DIR="$RUN" bash run.sh > "$RUN/run.log" 2>&1   # run_in_background: true
```

`TD_START_FROM` 앞 시나리오는 `건너뜀` 이 되고 의존을 막지 않는다. 앞 시나리오가 만든 기기 상태가 남아 있을 때만 쓴다. 쓰기 전에 `td-probe.sh` 로 기기 상태를 확인하고 사용자 확인을 받는다.

## 5. 결과

run 이 끝나면 순서대로 한다.

1. `~/.claude/skills/test-drive/scripts/td-finalize.sh <run 폴더 절대경로>` 를 실행한다. 폴더 이름에 결과 접미사가 붙고 `result.md` 초안이 생긴다. 이후 출력된 새 경로를 쓴다.
2. `references/result-format.md` 를 읽고 `result.md` 의 `<채움>` 을 채운다. 실행 직후 판정만 쓴다.
3. `failures.md` 의 `미분류` 행에 분류 · 원인 · 조치를 채운다.
4. `summary.md` 를 갱신한다.

재판정은 `summary.md` · `failures.md` 에만 쓴다. 형식과 결함 분류표는 `references/summary-format.md` 에 있다.

결함 분류가 `앱 버그` 면 보고하고 멈춘다. `스크립트 결함` · `기준 결함` · `사람 진행 오류` 면 `scenario.md` 를 고치고 `run.sh` 를 다시 생성해 재실행한다.

## 하지 않는 것

- 앱 코드를 고치지 않는다. 앱 버그는 보고하고 멈춘다.
- 테스트 코드(Espresso · Robolectric · JUnit)를 쓰지 않는다. 기기를 직접 조작한다.
- 확인 없이 1단계에서 2단계로 넘어가지 않는다.
- 기대 동작을 추측으로 지어내지 않는다. 자료가 없으면 1단계에서 멈춘다.
- 감지 조건 없는 `[human]` 을 실행하지 않는다.
- `[auto]` 로 가능한 조작을 `[human]` 으로 빼지 않는다.
- 의존이 없는 시나리오는 하나가 실패해도 건너뛰지 않는다.
- `run.sh` 를 포그라운드로 실행하지 않는다.
