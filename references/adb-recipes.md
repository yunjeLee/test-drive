# adb 레시피

`scripts/td-lib.sh` 를 source 한 뒤 쓴다. `td_adb` 는 절대경로 adb + `ANDROID_SERIAL` 을 적용한다.

## 기기

| 목적 | 명령 |
|---|---|
| 연결 기기 | `"$ADB" devices -l` |
| AVD 목록 | `"$HOME/Library/Android/sdk/emulator/emulator" -list-avds` |
| 에뮬레이터 부팅 | `td_boot_wait <avd 이름>` |
| OS 버전 | `td_adb shell getprop ro.build.version.release` |
| 화면 깨우기 | `td_adb shell input keyevent KEYCODE_WAKEUP` |

## 앱

| 목적 | 명령 |
|---|---|
| 설치 | `td_install <apk>` · debug 는 `td_install <apk> -t` |
| 삭제 | `td_adb uninstall $TD_PKG` — 로그인이 삭제된다. Bash 도구로 직접 실행하면 hook 이 확인을 묻는다 |
| 실행 | `td_launch` |
| 강제 종료 | `td_adb shell am force-stop $TD_PKG` |
| 데이터 삭제 | `td_adb shell pm clear $TD_PKG` — Bash 도구로 직접 실행하면 hook 이 확인을 묻는다 |

hook 은 Bash 도구 호출만 검사한다. `run.sh` 안의 uninstall · `pm clear` 는 확인 없이 실행된다. 스텝이나 복구에 넣으려면 3단계 `scenario.md` 검토에서 사용자 확인을 받는다.
| 버전 확인 | `td_adb shell dumpsys package $TD_PKG \| grep versionName` |
| 서명 확인 | `td_apk_sig <apk>` — 두 APK 가 서로 덮이는지 미리 본다 |
| 설치본 서명 | `td_installed_sig` — 기기의 base.apk 를 pull 해 서명을 출력한다. 미설치면 1 |

## 화면 조작

| 목적 | 명령 |
|---|---|
| 화면 요약 | `scripts/td-probe.sh [xml] [술어]` — `TOP` · `PKGS` · `IDS` · `TEXT` · `CLICK` · `MATCH` |
| 좌표 찾기 | `td_ui_find "<python 술어>"` — 1회 dump |
| 뜰 때까지 대기 | `td_wait_ui "<python 술어>" [초]` — 2초 간격 재시도. 기본 `TD_TAP_WAIT` 초 |
| 탭 | `td_tap "<python 술어>" "<설명>"` — `td_wait_ui` 로 찾는다 |
| 좌표 직접 탭 | `td_adb shell input tap <x> <y>` |
| 텍스트 입력 | `td_adb shell input text "<문자열>"` |
| 스와이프 | `td_adb shell input swipe <x1> <y1> <x2> <y2> <ms>` |
| 뒤로 · 홈 · 최근 | `td_adb shell input keyevent KEYCODE_BACK` · `KEYCODE_HOME` · `KEYCODE_APP_SWITCH` |

술어는 노드 속성 getter `g` 로 쓴다.

```
"'로그인' in g('text')"
"g('resource-id').endswith('btn_login')"
"g('content-desc')=='MyApp' and g('clickable')=='true'"
```

## task · recents

| 목적 | 명령 |
|---|---|
| 현재 화면 | `td_top` |
| 앱 task id 목록 | `td_tasks` |
| task 전부 제거 | `td_clear_tasks` |
| task 하나 제거 | `td_adb shell am stack remove <id>` |
| task 상세 | `td_adb shell dumpsys activity recents \| grep -A12 "#<id> "` |

## 알림 · 권한 · 딥링크

| 목적 | 명령 |
|---|---|
| 활성 알림 | `td_adb shell cmd notification list \| grep $TD_PKG` |
| 알림 패널 열기 | `td_adb shell cmd statusbar expand-notifications` |
| 권한 부여 | `td_adb shell pm grant $TD_PKG <권한>` |
| 권한 상태 | `td_adb shell dumpsys package $TD_PKG \| grep <권한>` |
| 딥링크 | `td_adb shell am start -a android.intent.action.VIEW -d "<url>" $TD_PKG` |

## 로그 · 백그라운드

| 목적 | 명령 |
|---|---|
| logcat 수집 시작 | `td_logcat_start "$TD_RUN_DIR/evidence/logcat.txt" <logcat 인자…>` |
| 구간 시작점 | `m=$(td_mark <파일>)` — 현재 줄 수. 파일이 없으면 `0` |
| 구간 로그 | `td_since <파일> "$m"` — 시작점 다음 줄부터 |
| 백그라운드 실행 | `td_bg <명령…>` — 종료 시 kill 된다 |
| 포트 포워딩 | `td_forward <로컬포트> <원격>` — 종료 시 제거된다 |
| 정리 | `td_cleanup` — trap 이 EXIT 에서 호출한다. TERM · INT 도 EXIT 를 거친다 |
| 중단 | `pkill -f "bash run.sh"` |

## 시나리오 · 판정 흐름

| 목적 | 명령 |
|---|---|
| 시나리오 실행 | `td_scenario <번호> "<제목>" <본문함수> <복구함수\|-> [의존번호…]` |
| 사전조건 | `td_require "<설명>" '<조건>' \|\| return 2` |
| 스텝 | `td_step <N.M> "<설명>" '<명령>' \|\| return 1` |
| 판정 | `td_check <N.M> "<설명>" '<기준>'` |
| 요약 | `td_summary` — 시나리오별 상태 · `TD_SUFFIX` · `TD_EXIT` |
| 시작 번호 | `TD_START_FROM=<번호>` — 앞 시나리오는 `건너뜀` |

## 판정

| 목적 | 명령 |
|---|---|
| 크래시 버퍼 비우기 | `td_crash_clear` |
| 크래시 개수 | `td_crash_count` |
| 크래시 원문 저장 | `td_crash_dump <이름>` — `evidence/<이름>.txt` |
| 액티비티 시작 로그 | `td_adb logcat -d \| grep -m1 "START u0 .*$TD_PKG"` |
| 실패 캡처 | `td_capture_failure <N.M> <step\|check> "<설명>"` — `td_step` · `td_check` 가 실패 시 호출한다. `fail/<SID>_<종류>` · `failures.md` 행 |

## 함정

- `adb` 는 PATH 에 없다. 절대경로를 쓴다.
- 기기가 2대 이상이면 `ANDROID_SERIAL` 없이는 명령이 실패한다.
- 활성 알림은 `cmd notification list` 로 본다. `dumpsys notification` 은 기록 섹션까지 잡혀 오판한다.
- `pm revoke` 는 앱을 죽이고 task 의 activity 를 제거한다. recents 카드가 사라진다.
- `uiautomator dump` 는 애니메이션 중에 실패한다. 조작 뒤 `sleep` 을 준다.
- `adb install` 은 실패 시 출력 끝에 빈 줄을 붙인다. `| tail -1` 로 결과를 읽으면 실패가 빈 문자열로 잡힌다. 종료코드로 판정한다.
- `install -r` 는 두 APK 의 서명이 같아야 한다. 배포본(App Distribution·Play)이 깔린 기기에 로컬 debug 빌드를 덮으면 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` 이 난다. 이때는 `uninstall` 이 필요하고 로그인이 날아간다.
- debug APK 는 `-t` 없이 설치되지 않는 경우가 있다(`testOnly`).
- R8 이 바꾼 클래스명은 `mapping.txt` 로 확인한다. 난독화가 얽힌 크래시는 release 에서만 재현된다.
- `dumpsys activity activities` 의 `ActivityRecord` 줄에는 닫힌 activity 이력이 섞인다. 실제 스택은 `* Hist` 줄만 본다.
- 잠금 화면에서는 `topResumedActivity` 줄이 없어 `td_top` · `td-probe.sh` 의 `TOP` 이 빈 값이다. 실행 전에 잠금을 해제한다.
- 실행 중인 `run.sh` 를 수정하지 않는다. bash 는 파일을 이어 읽으므로 엉뚱한 줄이 실행된다.
