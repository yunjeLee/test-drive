# test-drive run 산출물 구조 · 실패 분류 · 자동화 개선 계획

- 승인: 사용자 2026-09-17
- 브랜치: `feat/run-structure`
- 근거 세션: `~/.claude/projects/-Users-yunjelly-AndroidStudio-dalla/72d62787-b93e-40d6-845e-84edfedf3cde.jsonl` (DCL-1538 온보딩 테스트, run 001~006)
- 근거 산출물: `/Users/yunjelly/AndroidStudio/dalla/.test-drive/2026-09-17-onboarding-dcl1538/` (읽기 전용)

## 진행 규칙

- 단계 0 → 5 순서로 진행한다.
- 단계가 끝나면 검증 결과를 보고하고 사용자 확인 후 다음 단계로 간다.
- 커밋은 사용자가 요청할 때 단계 단위로 한다.

## 범위

| 포함 | 항목 |
|---|---|
| 구조 | 작업 폴더 · run 폴더 명명, `fail/` · `evidence/`, `summary.md` · `failures.md`, run.sh 스냅샷 |
| 분류 | 결함 분류 6종 |
| lib | 시나리오 실행기 · 의존 · 이어서 실행 · 정리 trap · logcat 수집 · 기준점 · UI 대기 · 설치본 서명 |
| 스크립트 | `td-probe.sh` · `td-new-run.sh` · `td-finalize.sh` |
| 서브에이전트 | A1 코드 조사 — `references/agent-prompts.md` 템플릿 + 내장 `Explore` |
| hook | H1 포그라운드 run.sh 차단 · H2 uninstall/pm clear 확인 |

| 제외 | 이유 |
|---|---|
| `td-dryrun.sh` · `td-devices.sh` · 데스크톱 알림 | 다음 테스트 후 판단 |
| 시나리오 검토 · 실패 분류 서브에이전트 | 다음 테스트 후 판단 |
| 실행 중 run.sh 수정 차단 hook · Stop hook | 다음 테스트 후 판단 |
| `[human]` 감지 식별자 규칙 · `(도출)` 표시 · 재판정 기록 위치 외 문서 규칙 · 라벨 질문 외 1단계 변경 | 다음 테스트 후 판단 |

## 결정

- 작업 폴더는 `<일감번호>-<요약>` 으로 만든다. 일감번호가 없으면 `<YYYY-MM-DD>-<요약>` 으로 만든다. — 일감번호가 폴더 끝에 묻혀 사용자가 찾지 못했다.
- run 폴더는 시작 시 `NNN_S<시작 2자리>-S<끝 2자리>` 로 만들고 종료 후 `_<TD_SUFFIX>` 를 붙인다. — 001~004 가 같은 이름이라 구별되지 않았다.
- run 라벨 질문을 없앤다. — 명명이 자동이다.
- 실패 캡처는 `fail/<SID>_<종류>.png` · `.xml` 로 저장한다. SID 는 `S%02d.<스텝>` 이다(예: `S08.4`). 종류는 `step` · `check` 다. — `fail-01` 은 run 마다 뜻이 달랐다.
- 같은 이름이 이미 있으면 `_2`, `_3` 을 붙인다.
- 판정 근거 파일은 `$TD_RUN_DIR/evidence/` 에 쓴다.
- `td_require_env` 가 실행 중인 `run.sh` 를 run 폴더에 복사한다. — 001 을 돌린 run.sh 가 남지 않았다.
- 작업 폴더에 `failures.md` 를 둔다. `td_capture_failure` 가 한 줄을 자동 추가하고 agent 가 5단계에서 분류 · 원인 · 조치를 채운다.
- 작업 폴더에 `summary.md` 를 둔다. 시나리오별 최종 판정과 run 목록을 agent 가 5단계에서 갱신한다. — 최종 결론이 채팅에만 있었다.
- run 의 `result.md` 는 실행 직후 판정만 쓴다. 재판정은 `summary.md` · `failures.md` 에만 쓴다.
- `td_check` 인자를 `<번호> <설명> <기준>` 으로 바꾼다. 구 인자 호환 코드를 넣지 않는다. — dalla 기존 run.sh 는 일회성이다.
- `td_abort` 를 삭제한다. `td_scenario` 가 대체한다.
- 시나리오 의존은 `scenario.md` 의 `의존: 시나리오 N` 으로 선언한다. 의존 대상이 `PASS` · `건너뜀` 이 아니면 기기를 조작하지 않고 `실행불가` 로 기록한다. — S1 실패 후 S2 가 Play 앱을 실행했고 연쇄 FAIL 이 났다.
- SKILL.md 의 "하나가 실패해도 남은 시나리오를 건너뛰지 않는다" 를 "의존이 없는 시나리오는 하나가 실패해도 건너뛰지 않는다" 로 바꾼다.
- 2단계에 설치본 서명 비교를 넣는다. 다르면 uninstall(로그인 삭제) 필요를 실행 전에 확인받는다. — F01.
- 4단계 앞에 사전 탐색(probe)을 필수로 넣는다. 클린 설치 → 실행 → 메인 도달까지 `td-probe.sh` 로 화면을 확인하고 가로막는 화면을 시나리오 1 스텝에 넣는다. — F02 · F04.
- 중단은 `pkill -f "bash run.sh"` 한 줄로 한다. 정리는 trap 이 한다.
- 재실행은 `td-new-run.sh` 로 새 run 을 만들고 `TD_START_FROM` 으로 이어서 실행한다.
- 서브에이전트는 커스텀 에이전트 파일을 만들지 않는다. 프롬프트 템플릿을 내장 `Explore` 에 넘긴다. — 개인 스킬은 에이전트 정의를 동봉하지 못한다.
- hook 은 SKILL.md frontmatter 에 둔다. hook 스크립트는 test-drive 명령이 아니면 출력 없이 exit 0 한다. — 스킬 hook 은 호출 후 세션 끝까지 유지된다.
- hook command 는 `bash ~/.claude/skills/test-drive/hooks/guard-bash.sh` 로 쓴다.
- 테스트는 레포 `tests/` 에 남긴다.
- 4단계 후 새 컨텍스트 서브에이전트에 SKILL.md · references 만 주고 적용 검토를 받는다.

## 제약

- run.sh 는 macOS `/bin/bash` 3.2 로 실행된다. 연관 배열 · `${v,,}` · `mapfile` 을 쓰지 않는다.
- `~/.claude/skills/test-drive` 는 이 레포의 심볼릭 링크다. 수정은 즉시 실사용에 반영된다.
- JSON 파싱은 `python3` 로 한다. `jq` 를 쓰지 않는다.
- `/Users/yunjelly/AndroidStudio/dalla/` 아래 파일을 수정하지 않는다.
- 이 세션에서 `/test-drive` 스킬을 호출하지 않는다. — hook 이 작업 세션에 걸린다.
- 앱 코드 수정 · 테스트 코드(Espresso 등) 작성 금지 규칙은 그대로 둔다.

## 명세

### 결함 분류

| 분류 | 판정 근거 | 다음 |
|---|---|---|
| 앱 버그 | 스텝이 의도대로 실행됐고 앱 동작이 기준과 다르다 | 보고하고 멈춘다 |
| 스크립트 결함 | 좌표 · 문구 · 타이밍 · 감지 조건 · 사전조건 · 빌드 변형이 틀렸다 | run.sh 를 고쳐 재실행한다 |
| 기준 결함 | 판정식 또는 기대 동작 해석이 틀렸다 | scenario.md 를 고치고 사용자 확인 후 재실행한다 |
| 사람 진행 오류 | `[human]` 스텝을 다르게 수행했다 | 안내 문구를 고쳐 재실행한다 |
| 연쇄 | 앞선 실패의 여파다 | 원 실패 ID 를 원인 칸에 쓴다 |
| 미결 | 정책 확인이 필요하다 | `미결: <질문> / 답할 사람: <누구>` 로 남긴다 |

### 작업 폴더 트리

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

### `scripts/td-lib.sh`

환경변수

| 이름 | 필수 | 기본값 |
|---|---|---|
| `TD_PKG` | 필수 | — |
| `TD_RUN_DIR` | 필수 | — |
| `ANDROID_SERIAL` | 기기 2대 이상일 때 필수 | — |
| `ADB` | 선택 | SDK 경로 → PATH |
| `TD_START_FROM` | 선택 | `1` |
| `TD_TAP_WAIT` | 선택 | `10` (초) |

`TD_WORK_DIR` 는 `TD_RUN_DIR` 의 두 단계 위 폴더다.

함수 — 추가

| 함수 | 동작 |
|---|---|
| `td_bg <명령…>` | 백그라운드 실행 후 PID 를 `TD_BG_PIDS` 에 더한다 |
| `td_forward <로컬포트> <원격>` | `adb forward tcp:<로컬포트> <원격>` 후 포트를 `TD_FWD_PORTS` 에 더한다 |
| `td_cleanup` | `TD_BG_PIDS` kill · `TD_FWD_PORTS` 각각 `forward --remove` · `TD_TMP` 삭제 |
| trap | `EXIT` → `td_cleanup` · `TERM` → `exit 143` · `INT` → `exit 130` |
| `td_logcat_start <파일> <logcat 인자…>` | `td_bg` 로 `logcat -v time <인자>` 를 파일에 쓴다 |
| `td_mark <파일>` | 현재 줄 수를 출력한다. 파일이 없으면 `0` |
| `td_since <파일> <mark>` | mark 다음 줄부터 출력한다 |
| `td_wait_ui <술어> [초]` | 2초 간격으로 `td_ui_find` 를 재시도한다. 성공 시 좌표를 출력하고 0, 시간 초과 시 1. 기본 초 = `TD_TAP_WAIT` |
| `td_installed_sig` | `pm path $TD_PKG` 의 base.apk 를 pull 해 `td_apk_sig` 결과를 출력한다. 미설치면 1 |
| `td_scenario <번호> <제목> <본문함수> <복구함수\|-> [의존번호…]` | 아래 규칙 |

`td_scenario` 규칙

- 로그 머리줄: `════════ 시나리오 <번호> — <제목>`.
- `번호 < TD_START_FROM` 이면 상태 `건너뜀` 으로 기록하고 본문 · 복구를 실행하지 않는다.
- 의존 번호 중 상태가 `PASS` · `건너뜀` 이 아닌 것이 있으면 상태 `실행불가`, 사유 `의존 S<번호> <상태>` 로 기록하고 본문 · 복구를 실행하지 않는다.
- 본문 반환 0 이고 이 시나리오의 `td_check` FAIL 이 0 이면 `PASS` 다.
- 본문 반환 0 이고 FAIL 이 1 이상이면 `FAIL` 이다.
- 본문 반환 1 이면 `중단` 이고 사유는 실패한 스텝 SID 다.
- 본문 반환 2 이면 `실행불가` 이고 사유는 `td_require` 설명이다.
- 복구 함수는 본문을 실행했으면 반환값과 무관하게 실행한다.
- 상태는 인덱스 배열 `TD_SCN_STATUS[번호]` · `TD_SCN_REASON[번호]` 에 담는다.

함수 — 변경

| 함수 | 변경 |
|---|---|
| `td_require_env` | `fail/` · `evidence/` 생성 · `$0` 이 파일이면 `$TD_RUN_DIR/run.sh` 로 복사 · `failures.md` 가 없으면 머리행 생성 |
| `td_tap <술어> <설명>` | `td_wait_ui` 로 찾는다 |
| `td_step <번호> <설명> <명령>` | 실패 시 `td_capture_failure <번호> step <설명>` · 실패 SID 기록 · 1 반환 |
| `td_check <번호> <설명> <기준>` | 로그 `PASS  <번호> <설명>` / `FAIL  <번호> <설명>` · FAIL 시 `td_capture_failure <번호> check <설명>` |
| `td_require <설명> <조건>` | 실패 시 사유를 현재 시나리오에 기록하고 1 반환 |
| `td_capture_failure <번호> <종류> <설명>` | `fail/<SID>_<종류>` 로 png · xml 저장 · `failures.md` 에 행 추가 |
| `td_summary` | 아래 출력 · `TD_EXIT` 값을 반환코드로 돌려준다 |
| `td_crash_dump [이름]` | `evidence/<이름>.txt` 에 쓴다 |

함수 — 삭제: `td_abort`.

`failures.md` 머리행과 자동 행

```
| ID | run | 스텝 | 종류 | 분류 | 원인 | 조치 | 캡처 |
|---|---|---|---|---|---|---|---|
| F05 | 004 | S08.4 | check | 미분류 | 종료 안내 노출 중 단계 조회 없음 | - | runs/004_S02-S12/fail/S08.4_check.png |
```

- ID 는 기존 `| F` 행 수 + 1 을 2자리로 쓴다.
- run 은 run 폴더 이름 앞 3자리다.
- 원인 칸의 자동 값은 스텝 설명이다. agent 가 5단계에서 원인으로 바꾼다.
- 종류 `human` 행은 agent 가 수동으로 추가한다.

`td_summary` 출력

```
[hh:mm:ss] S01 PASS
[hh:mm:ss] S02 실행불가 의존 S01 중단
[hh:mm:ss] 판정 PASS 3 / FAIL 1
TD_SUFFIX=FAIL-1_중단@S01.2_실행불가-1
TD_EXIT=1
```

- `TD_SUFFIX` 조각 순서: `FAIL-<FAIL 시나리오 수>` · `중단@<첫 중단 SID>` · `실행불가-<실행불가 시나리오 수>`.
- 해당 조각만 `_` 로 잇는다. 조각이 없으면 `완료` 다.
- `TD_EXIT` 는 `완료` 일 때 0, 아니면 1 이다.

### `scripts/td-new-run.sh <작업폴더> <시작번호> <끝번호>`

- `runs/` 의 기존 최대 3자리 번호 + 1 로 `runs/NNN_S<시작 2자리>-S<끝 2자리>` 를 만든다.
- 만든 폴더의 절대경로 한 줄만 출력한다.

### `scripts/td-probe.sh [xml] [술어]`

- 인자가 없으면 기기 화면을 dump 한다. `ANDROID_SERIAL` · `ADB` 를 쓴다.
- xml 을 주면 그 파일을 분석한다.
- 출력: `TOP <topResumedActivity>`(기기 모드만) · `PKGS` · `IDS`(`:id/` 뒤 이름) · `TEXT`(text · content-desc) · `CLICK <x> <y> <id|text>`(clickable 노드).
- 술어를 주면 매칭 노드의 속성 전체를 출력한다. 술어 문법은 `td_ui_find` 와 같다.

### `scripts/td-finalize.sh <run폴더>`

- `run.log` 의 마지막 `TD_SUFFIX=` 값이 없으면 `실행이 끝나지 않음` 을 출력하고 exit 1 한다.
- 폴더 이름이 이미 `_<접미사>` 로 끝나면 이름을 바꾸지 않는다.
- 폴더 이름을 `<현재 이름>_<TD_SUFFIX>` 로 바꾼다.
- `failures.md` 의 이전 경로를 새 경로로 바꾼다.
- `result.md` 가 없으면 초안을 만든다. 시각(첫 · 마지막 로그 시각) · 로그 · 시나리오별 상태 · 시나리오별 `PASS  ` / `FAIL  ` 원문 줄을 채운다. 기기 · 빌드 · 시나리오 · 근거 자료 · 결함 칸은 `<채움>` 으로 둔다.
- 새 폴더의 절대경로를 출력한다.

### `hooks/guard-bash.sh`

- stdin JSON 을 `python3` 로 읽는다. `tool_name` 이 `Bash` 가 아니면 exit 0.
- H1: `command` 가 정규식 `(^|[;&|[:space:]])(bash|sh)[[:space:]]+([^;&|[:space:]]*/)?run\.sh([[:space:]]|$)` 에 맞고 `tool_input.run_in_background` 가 true 가 아니면 deny 한다. 사유: `test-drive: run.sh 는 run_in_background: true 로 실행한다`.
- H2: `command` 에 `adb` 또는 `td_adb` 와 함께 `uninstall` 이 있거나 `pm clear` 가 있으면 ask 한다. 사유: `test-drive: 앱 데이터·로그인이 삭제된다`.
- 둘 다 아니면 출력 없이 exit 0.
- 출력 형식: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask","permissionDecisionReason":"…"}}`.

SKILL.md frontmatter

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "bash ~/.claude/skills/test-drive/hooks/guard-bash.sh"
```

### `tests/`

- `tests/fake-adb` : 받은 인자를 `$FAKE_ADB_LOG` 에 한 줄씩 쓴다. `$FAKE_DIR` 의 파일로 응답한다(`ui.xml` · `top.txt` · `logcat.txt`). `logcat -v time` 은 종료될 때까지 sleep 한다. `install` 은 `Success` 를 출력한다.
- `tests/run-tests.sh` : `/bin/bash` 로 모든 케이스를 실행하고 `PASS n / FAIL n` 을 출력한다. 하나라도 실패하면 exit 1.

## 단계

### 0. 테스트 작성
- `tests/fake-adb` · `tests/run-tests.sh` 를 작성한다.
- 케이스:
  - T1 S1 의 `td_step` 실패 → S1 `중단`, 의존 S2 `실행불가`, fake-adb 로그에 S2 명령 없음.
  - T2 `TD_START_FROM=2` → S1 `건너뜀`, 의존 S2 실행.
  - T3 `td_check 8.4` FAIL → `fail/S08.4_check.png` · `.xml` 생성, `failures.md` 에 `F01 | <run> | S08.4 | check | 미분류` 행.
  - T4 `td_summary` 의 `TD_SUFFIX` 가 T1 에서 `중단@S01.1_실행불가-1`, 전부 PASS 에서 `완료`.
  - T5 `td_bg sleep 300` 후 run.sh 에 `kill -TERM` → sleep 프로세스 없음.
  - T6 ui.xml 을 3초 뒤 만들 때 `td_tap` 성공.
  - T7 run 폴더에 `run.sh` 스냅샷 존재.
  - T8 `td-new-run.sh` 가 기존 `001_*` · `002_*` 옆에 `003_S02-S12` 생성.
  - T9 `td-finalize.sh` 가 폴더 이름에 접미사를 붙이고 `failures.md` 경로를 바꾸고 `result.md` 초안을 만든다. `TD_SUFFIX` 없는 run.log 에는 exit 1.
  - T10 `td-probe.sh <xml>` 이 `IDS` · `TEXT` · `CLICK` 줄을 출력한다.
  - T11 guard-bash: 포그라운드 `bash run.sh` → deny · `START_FROM=2 bash run.sh` 포그라운드 → deny · 백그라운드 → 출력 없음 · `bash -n run.sh` → 출력 없음 · `adb -s X uninstall pkg` → ask · `td_adb shell pm clear pkg` → ask · `ls` → 출력 없음 · `tool_name=Edit` → 출력 없음.
- 완료 기준: `bash tests/run-tests.sh` 가 실패를 보고한다(기능 미구현).

### 1. `td-lib.sh`
- 명세대로 수정한다.
- 완료 기준: `bash -n scripts/td-lib.sh` 통과 · `/bin/bash tests/run-tests.sh` 에서 T1~T7 통과.

### 2. 스크립트
- `td-new-run.sh` · `td-probe.sh` · `td-finalize.sh` 를 작성하고 실행 권한을 준다.
- 완료 기준: T8~T10 통과.

### 3. hook
- `hooks/guard-bash.sh` 작성 · SKILL.md frontmatter 추가.
- 완료 기준: T11 통과.

### 4. 문서
- `SKILL.md`
  - 산출물 위치를 새 트리 · 명명 규칙으로 바꾼다.
  - 1단계 확인 블록에 `일감: <번호 | 없음>` 을 넣는다.
  - 2단계에 `td_installed_sig` · `td_apk_sig` 비교와 uninstall 사전 확인을 넣는다.
  - 3단계 코드 조사를 `references/agent-prompts.md` 의 A1 템플릿으로 `Explore` 에 맡긴다.
  - 4단계 앞에 사전 탐색(`td-probe.sh`)을 넣는다.
  - 4단계를 `td-new-run.sh` 생성 · 백그라운드 실행 · `pkill` 중단 · `TD_START_FROM` 재실행 · 실행 중 run.sh 수정 금지로 바꾼다. 라벨 질문을 지운다.
  - 5단계를 `td-finalize.sh` → `result.md` 채움 → `failures.md` 분류 → `summary.md` 갱신으로 바꾼다. 분류표는 `summary-format.md` 를 가리킨다.
  - 하지 않는 것의 시나리오 건너뛰기 규칙을 결정대로 바꾼다.
- `references/scenario-format.md`: `의존:` 문법 · `td_check <번호>` · run.sh 생성 예시를 `td_scenario` 기반으로 교체 · `evidence/` 규칙.
- `references/result-format.md`: 결함 6종 · 캡처 경로 `fail/<SID>_<종류>.png` · 실행 직후 판정만 쓰는 규칙.
- `references/summary-format.md` (신규): `summary.md` 형식(시나리오별 최종 판정 + 근거 run, run 목록 = 번호 · 범위 · 결말 · 재실행 사유) · `failures.md` 형식 · 결함 분류표.
- `references/agent-prompts.md` (신규): A1 템플릿. 입력 = 변경 범위(커밋 · 브랜치) · 검증 화면 · 플로우. 출력 = 화면 요소 표(화면 · 요소 · resource-id 또는 문구 · `경로:줄`) · API 표(경로 · 호출 위치 · 로그 태그) · 첫 실행 경로의 가로막는 화면 · debug 판정 수단(로그 인터셉터 · WebView 디버깅 · SharedPreferences 암호화 여부). 제약 = 읽기 전용 · 기기 조작 금지.
- `references/adb-recipes.md`: 새 함수 행 추가 · `td_abort` 참조 제거 · 함정 추가 "`dumpsys activity activities` 의 `ActivityRecord` 줄에는 닫힌 activity 이력이 섞인다. 실제 스택은 `* Hist` 줄만 본다."
- `README.md`: 산출물 트리 · 구성 표(스크립트 · hooks · tests · 신규 references).
- 완료 기준:
  - `grep -rn "td_abort\|fail-01\|<3자리 순번>-<라벨>\|라벨을 제안" SKILL.md README.md references/` 결과 0건.
  - 문서에 적힌 스크립트 · 함수 이름이 전부 `scripts/` 에 존재한다(`grep` 대조).

### 5. 통합 검증
- fake-adb 로 SKILL.md 순서를 재현한다: `td-new-run.sh` → `scenario-format.md` 예시 run.sh 실행 → `td-finalize.sh`. 산출물 트리가 명세 트리와 같다.
- 새 컨텍스트 서브에이전트(`general-purpose`)에 SKILL.md · references 만 주고 "예시 시나리오로 run.sh 를 생성하라, 모호한 곳을 보고하라" 를 맡긴다. 생성물이 `bash -n` 을 통과하고 보고된 모호함을 반영한다.
- S25 가 연결돼 있으면 `td_installed_sig` · `td-probe.sh` 를 1회 실행한다. 연결돼 있지 않으면 미검증으로 보고한다.
- 완료 기준: `/bin/bash tests/run-tests.sh` 전 케이스 통과 · 위 세 항목 결과 보고.

## 미결

- 미결: frontmatter hook 이 실제 세션에서 `~` 경로로 실행되는가 / 답할 사람: 사용자 — 새 세션에서 `/test-drive` 호출 후 포그라운드 `bash run.sh` 차단 여부 확인.
- 미결: Play 설치본 base.apk 를 `adb pull` 로 가져올 수 있는가 / 답할 사람: 5단계 실기기 확인.
- 미결: SKILL.md `context: fork` 지원 여부 / 답할 사람: 추가 문서 확인 — 이번 계획은 의존하지 않는다.
