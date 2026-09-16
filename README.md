# test-drive

사람이 손으로 하던 Android E2E 를 agent 가 대신 돌리는 스킬.

기능 검증과 크래시 재현을 같은 엔진으로 처리한다. 성공기준이 부호를 담는다 — `FATAL 0건` / `FATAL ≥1건`.

## 설치

```bash
ln -s "$(pwd)" ~/.claude/skills/test-drive
```

## 쓰는 법

```
/test-drive
```

1. 성격 판정 → 자료 요구 → 확인
2. 기기 · 빌드 변형 선택
3. `scenario.md` 작성 → 검토
4. `run.sh` 생성 → 백그라운드 실행
5. `result.md` 작성

## 산출물

대상 프로젝트 루트에 쌓인다.

```
.test-drive/2026-09-15-splash-crash/
├── scenario.md                     # 시나리오 + 성공기준 (단일 출처)
├── run.sh                          # scenario.md 에서 생성
└── runs/
    ├── 001-수정전-재현확인/{result.md, run.log}
    └── 002-수정후-검증/{result.md, run.log, fail-01.png}
```

## 요구사항

| 항목 | 확인 |
|---|---|
| adb | `~/Library/Android/sdk/platform-tools/adb` 또는 PATH |
| python3 | `td_ui_find` 가 화면 XML 을 파싱한다 |
| 에뮬레이터 (선택) | `~/Library/Android/sdk/emulator/emulator` |

## 구성

| 파일 | 내용 |
|---|---|
| `SKILL.md` | 5단계 흐름 · `[auto]`/`[human]` 가르는 기준 |
| `references/scenario-format.md` | `scenario.md` 문법 · 템플릿 |
| `references/result-format.md` | `result.md` 템플릿 |
| `references/adb-recipes.md` | 기기 · 조작 · 판정 레시피 · 함정 |
| `scripts/td-lib.sh` | `run.sh` 가 source 하는 공용 함수 |

## 범위 밖

- 앱 코드 수정. 앱 버그는 보고하고 멈춘다.
- 자료 없는 시나리오 작성. 기대 동작의 출처를 받지 못하면 1단계에서 멈춘다.
- 테스트 코드(Espresso · Robolectric · JUnit) 작성.
- iOS.
