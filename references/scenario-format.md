# scenario.md 형식

`scenario.md` 는 단일 출처다. `run.sh` 는 여기서 생성한다. 수정은 `scenario.md` 에 하고 `run.sh` 를 다시 생성한다.

## 구조

```
# <작업 요약>
## 대상          — 기기·패키지·빌드·성격·근거 자료
## 빌드          — APK 를 만드는 명령 (없으면 생략)
## 시나리오 N    — 의존 / 사전조건 / 스텝 / 복구
```

시나리오가 여러 개면 `## 시나리오 1`, `## 시나리오 2` 로 잇는다.

## 의존

앞 시나리오의 결과가 전제인 시나리오는 제목 바로 아래에 한 줄을 쓴다.

```markdown
## 시나리오 3 — 온보딩 완료 후 재진입
의존: 시나리오 1, 시나리오 2
```

- 의존이 없으면 줄을 쓰지 않는다.
- 의존 대상이 `PASS` · `건너뜀` 이 아니면 시나리오는 기기를 조작하지 않고 `실행불가` 가 된다. 사유는 `의존 S<번호> <상태>` 다.
- 기기 상태만 공유하고 결과가 전제가 아니면 의존을 쓰지 않는다. 사전조건으로 확인한다.

## 스텝 문법

한 줄 = 한 스텝. `표기` · `설명` · `명령` 세 칸을 모두 채운다.

| 표기 | 셋째 칸 | 뜻 |
|---|---|---|
| `[auto]` | `명령:` | 실행할 bash. 0 종료면 통과 |
| `[human]` | `감지:` | 0 종료가 될 때까지 상한 없이 폴링할 bash |
| `[human:chat]` | `감지불가:` | 기기 상태로 판정할 수 없는 이유 한 줄 |
| `[check]` | `기준:` | 0 종료면 PASS, 아니면 FAIL |

`[human:chat]` 은 `td_human_chat "<설명>" <마커이름>` 으로 생성된다. 마커 이름은 스텝마다 다르게 붙인다.

스텝 번호는 시나리오 안에서 1 부터 매긴다. `run.sh` 에서는 `<시나리오>.<스텝>` 으로 쓴다. 시나리오 8 의 스텝 4 는 `8.4` 이고 실패 캡처 SID 는 `S08.4` 다.

## 성공기준

`[check]` 스텝이 성공기준이다. 부호를 명시한다.

| 용도 | `기준:` |
|---|---|
| 크래시 0건 | `[ "$(td_crash_count)" -eq 0 ]` |
| 크래시 1건 이상 | `[ "$(td_crash_count)" -ge 1 ]` |
| 특정 스택 | `td_adb logcat -d -b crash \| grep -q "SplashActivity.kt:48"` |
| 화면 도달 | `td_top \| grep -q HomeActivity` |
| 텍스트 존재 | `[ -n "$(td_ui_find "'로그인' in g('text')")" ]` |
| 텍스트가 뜰 때까지 대기 | `td_wait_ui "'로그인' in g('text')" 15` |
| 이 구간 로그에 API 호출 | `td_since "$TD_RUN_DIR/evidence/logcat.txt" "$m" \| grep -q "/v1/onboarding"` — `m` 은 구간 시작에서 `td_mark` 로 받는다 |

## 예시 — 어제 a1b2c3d4 재현

```markdown
# 2026-09-15 SplashActivity RemoteMessage BadParcelableException 재현

## 대상
| 항목 | 값 |
|---|---|
| 기기 | S25 `R3CXXXXXXXX` (Android 16 / One UI 8.5) |
| 패키지 | `com.example.app` |
| 빌드 | 구버전 = debug · 신버전 = release(minify) |
| 성격 | 크래시 재현 |
| 근거 자료 | Crashlytics `a1b2c3d4` 스택 — 사용자 제출 2026-09-15 |

release 가 필수다. debug 는 난독화가 없어 `RemoteMessage` 가 rename 되지 않는다.

## 빌드
```bash
./gradlew :app:clean :app:assembleDebug
./gradlew :app:assembleRelease --no-build-cache
grep -E "^com\.google\.firebase\.messaging\.RemoteMessage " app/build/outputs/mapping/release/mapping.txt
```

## 시나리오 1 — 알림 콜드스타트 task 가 업데이트 후 옛 intent 로 재실행된다

### 사전조건
- 알림 권한이 꺼져 있어 앱 안에 설정 이동 버튼이 보인다 — 확인: `td_adb shell dumpsys package $TD_PKG | grep -q "POST_NOTIFICATIONS: granted=false"`

### 스텝
1. `[auto]` 구버전 설치 후 기존 task 정리 — 명령: `td_install "$OLD_APK" -t && td_clear_tasks && td_launch && sleep 15 && td_adb shell input keyevent KEYCODE_HOME`
2. `[human]` 팔로우한 계정으로 방송을 켠다 — 감지: `td_adb shell cmd notification list | grep -q "$TD_PKG"`
3. `[auto]` task 제거 후 알림 탭으로 콜드스타트 — 명령: `td_clear_tasks && td_adb shell cmd statusbar expand-notifications && sleep 2 && td_tap "'라이브를 시작' in g('text')" "알림" && sleep 15`
4. `[human]` 앱 안에서 설정 이동 버튼을 눌러 설정 앱을 연다 — 감지: `td_top | grep -q com.android.settings`
5. `[auto]` 설정이 떠 있는 상태에서 신버전 설치 — 명령: `td_install "$NEW_APK" && sleep 5`
6. `[auto]` 뒤로가기로 설정을 닫는다 — 명령: `for i in 1 2 3 4 5; do td_top | grep -q com.android.settings || break; td_adb shell input keyevent KEYCODE_BACK; sleep 2; done`
7. `[auto]` 크래시 버퍼를 비우고 recents 카드를 탭한다 — 명령: `td_crash_clear && td_adb shell input keyevent KEYCODE_APP_SWITCH && sleep 5 && td_tap "g('resource-id').endswith('taskView') and g('content-desc')=='MyApp'" "recents 카드" && sleep 12`
8. `[check]` 크래시가 발생한다 — 기준: `[ "$(td_crash_count)" -ge 1 ]`
9. `[check]` 스택이 SplashActivity 를 가리킨다 — 기준: `td_adb logcat -d -b crash | grep -q "SplashActivity"`

### 복구
- 구버전 재설치 — `td_adb shell input keyevent KEYCODE_HOME; td_install "$OLD_APK" -t`

## 시나리오 2 — 재실행 후 홈으로 돌아간다
의존: 시나리오 1

### 스텝
1. `[auto]` 로그 구간 시작점을 잡고 앱 실행 — 명령: `m=$(td_mark "$TD_RUN_DIR/evidence/logcat.txt") && td_launch && sleep 10`
2. `[check]` HomeActivity 가 시작된다 — 기준: `td_since "$TD_RUN_DIR/evidence/logcat.txt" "$m" | grep -q HomeActivity`
```

## 규칙

- `## 대상` 의 `근거 자료` 행에 출처와 제출 시점을 쓴다. 출처는 Crashlytics 이슈 ID, 스택트레이스 제출, `edit-crash` Notion URL, 기획서·정책서 경로, 사용자 구술 중 하나다.
- agent 추측을 `근거 자료` 로 쓰지 않는다. 자료가 없으면 `scenario.md` 를 만들지 않는다.
- 한 스텝은 한 가지 일만 한다. 여러 명령을 `&&` 로 잇는 것은 같은 일의 부분일 때만 허용한다.
- **판정에 필요한 명령은 `&&` 로 잇는다.** `;` 로 이으면 마지막 명령의 종료코드만 남아 앞의 실패가 통째로 가려진다.
- `;` 는 실패해도 무방한 명령(상태 정리 등)에만 쓴다.
- 스텝 뒤의 `sleep` 은 명령 안에 둔다. 별도 스텝으로 만들지 않는다.
- `[human]` 의 `감지:` 는 그 스텝이 **끝났음**을 판정한다. 시작을 판정하지 않는다.
- 사전조건은 시나리오가 **시작할 수 있는가**만 본다. 결과를 판정하지 않는다.
- 복구는 앞 시나리오의 흔적을 지운다. 실패로 중단됐을 때도 실행된다.
- 판정 근거 파일(logcat · 응답 · dump · 크래시 원문)은 `$TD_RUN_DIR/evidence/` 에 쓴다. `td_crash_dump` 도 여기에 쓴다.
- logcat 은 `td_logcat_start` 로 한 번 켜고 `td_mark` · `td_since` 로 스텝 구간을 자른다.

## run.sh 생성 규칙

시나리오 N 하나 = 본문 함수 `sN` + 복구 함수 `rN` + `td_scenario` 한 줄.

```bash
#!/bin/bash
source ~/.claude/skills/test-drive/scripts/td-lib.sh
export TD_PKG=com.example.app
export TD_RUN_DIR=${TD_RUN_DIR:?td-new-run.sh 로 만든 run 폴더를 넘긴다}
export ANDROID_SERIAL=R3CXXXXXXXX
td_require_env

OLD_APK=/abs/app-debug.apk
NEW_APK=/abs/app-release.apk
td_logcat_start "$TD_RUN_DIR/evidence/logcat.txt" -s ActivityManager:I

# 작은따옴표가 든 명령은 함수로 뺀다
tap_notification() { td_tap "'라이브를 시작' in g('text')" "알림"; }
tap_recents_card() { td_tap "g('resource-id').endswith('taskView') and g('content-desc')=='MyApp'" "recents 카드"; }

# ── 시나리오 1 — 알림 콜드스타트 task 가 업데이트 후 옛 intent 로 재실행된다
s1() {
  td_require "알림 권한 꺼짐" 'td_adb shell dumpsys package $TD_PKG | grep -q "POST_NOTIFICATIONS: granted=false"' || return 2
  td_step 1.1 "구버전 설치 후 기존 task 정리" 'td_install "$OLD_APK" -t && td_clear_tasks && td_launch && sleep 15 && td_adb shell input keyevent KEYCODE_HOME' || return 1
  td_human "팔로우한 계정으로 방송을 켠다" 'td_adb shell cmd notification list | grep -q "$TD_PKG"'
  td_step 1.3 "task 제거 후 알림 탭으로 콜드스타트" 'td_clear_tasks && td_adb shell cmd statusbar expand-notifications && sleep 2 && tap_notification && sleep 15' || return 1
  td_human "앱 안에서 설정 이동 버튼을 눌러 설정 앱을 연다" 'td_top | grep -q com.android.settings'
  td_step 1.5 "설정이 떠 있는 상태에서 신버전 설치" 'td_install "$NEW_APK" && sleep 5' || return 1
  td_step 1.6 "뒤로가기로 설정을 닫는다" 'for i in 1 2 3 4 5; do td_top | grep -q com.android.settings || break; td_adb shell input keyevent KEYCODE_BACK; sleep 2; done' || return 1
  td_step 1.7 "크래시 버퍼를 비우고 recents 카드를 탭한다" 'td_crash_clear && td_adb shell input keyevent KEYCODE_APP_SWITCH && sleep 5 && tap_recents_card && sleep 12' || return 1
  td_crash_dump s1-crash
  td_check 1.8 "크래시가 발생한다" '[ "$(td_crash_count)" -ge 1 ]'
  td_check 1.9 "스택이 SplashActivity 를 가리킨다" 'grep -q "SplashActivity" "$TD_RUN_DIR/evidence/s1-crash.txt"'
}
r1() {
  td_adb shell input keyevent KEYCODE_HOME
  td_install "$OLD_APK" -t
}

# ── 시나리오 2 — 재실행 후 홈으로 돌아간다 (의존: 시나리오 1)
s2() {
  td_step 2.1 "로그 구간 시작점을 잡고 앱 실행" 'm=$(td_mark "$TD_RUN_DIR/evidence/logcat.txt") && td_launch && sleep 10' || return 1
  td_check 2.2 "HomeActivity 시작" 'td_since "$TD_RUN_DIR/evidence/logcat.txt" "$m" | grep -q HomeActivity'
}

td_scenario 1 "알림 콜드스타트 task 가 업데이트 후 옛 intent 로 재실행된다" s1 r1
td_scenario 2 "재실행 후 홈으로 돌아간다" s2 - 1
td_summary
```

| scenario.md | run.sh |
|---|---|
| 사전조건 | 본문 맨 앞 `td_require "<설명>" '<조건>' \|\| return 2` |
| `[auto]` | `td_step <N.M> "<설명>" '<명령>' \|\| return 1` |
| `[human]` | `td_human "<설명>" '<감지>'`. 번호 · `\|\| return` 을 붙이지 않는다 |
| `[human:chat]` | `td_human_chat "<설명>" <마커>`. 번호 · `\|\| return` 을 붙이지 않는다 |
| `[check]` | `td_check <N.M> "<설명>" '<기준>'`. FAIL 이어도 다음 판정을 계속한다 |
| 복구 | 함수 `rN`. 복구가 없으면 `td_scenario` 넷째 인자에 `-` |
| `의존: 시나리오 A, B` | `td_scenario` 다섯째 인자부터 `A B` |

- 본문 반환값: `0` = 끝까지 실행 · `1` = 스텝 실패(`중단`) · `2` = 사전조건 미충족(`실행불가`).
- 복구 함수는 본문을 실행했으면 반환값과 무관하게 실행된다.
- `td_scenario` 호출은 파일 끝에 번호 순으로 모은다. 마지막 줄은 `td_summary` 다.
- 본문과 복구에서 `exit` 를 쓰지 않는다. 남은 시나리오와 `td_summary` 가 실행되지 않는다.
- 명령에 작은따옴표가 들어가면 함수로 빼고 함수 이름을 넘긴다. 작은따옴표 문자열 안에 작은따옴표를 쓰면 문자열이 깨진다.
- `TD_RUN_DIR` · `TD_START_FROM` 은 파일에 쓰지 않는다. 실행할 때 환경변수로 넘긴다.
- `td_step` · `td_check` 는 실패 시 `fail/` 에 캡처하고 `failures.md` 에 행을 추가한다. 따로 호출하지 않는다.
