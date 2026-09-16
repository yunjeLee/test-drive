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
| 삭제 | `td_adb uninstall $TD_PKG` |
| 실행 | `td_launch` |
| 강제 종료 | `td_adb shell am force-stop $TD_PKG` |
| 데이터 삭제 | `td_adb shell pm clear $TD_PKG` |
| 버전 확인 | `td_adb shell dumpsys package $TD_PKG \| grep versionName` |
| 서명 확인 | `td_apk_sig <apk>` — 두 APK 가 서로 덮이는지 미리 본다 |

## 화면 조작

| 목적 | 명령 |
|---|---|
| 좌표 찾기 | `td_ui_find "<python 술어>"` |
| 탭 | `td_tap "<python 술어>" "<설명>"` |
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

## 판정

| 목적 | 명령 |
|---|---|
| 크래시 버퍼 비우기 | `td_crash_clear` |
| 크래시 개수 | `td_crash_count` |
| 크래시 원문 저장 | `td_crash_dump <이름>` |
| 액티비티 시작 로그 | `td_adb logcat -d \| grep -m1 "START u0 .*$TD_PKG"` |
| 실패 캡처 | `td_capture_failure "<설명>"` |

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
