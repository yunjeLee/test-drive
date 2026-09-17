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
4. 사전 탐색 → `run.sh` 생성 → 백그라운드 실행
5. `result.md` · `failures.md` · `summary.md` 작성

## 산출물

대상 프로젝트 루트에 쌓인다.

```
.test-drive/DCL1538-온보딩/                  # <일감번호>-<요약> · 없으면 <YYYY-MM-DD>-<요약>
├── scenario.md                               # 시나리오 + 성공기준 (단일 출처)
├── run.sh                                    # scenario.md 에서 생성
├── summary.md                                # 시나리오별 최종 판정 · run 목록
├── failures.md                               # 실패 목록 · 분류
└── runs/
    ├── 001_S01-S12_중단@S01.2/                # NNN_S<시작>-S<끝>_<결말>
    └── 004_S02-S12_FAIL-1_중단@S10.3/
        ├── result.md · run.log · run.sh      # run.sh = 실행한 스냅샷
        ├── fail/S08.4_check.png · .xml       # fail/<SID>_<종류>
        └── evidence/                         # 판정 근거 파일
```

## 요구사항

| 항목 | 확인 |
|---|---|
| adb | `~/Library/Android/sdk/platform-tools/adb` 또는 PATH |
| python3 | 화면 XML · hook 입력 JSON 파싱 · `result.md` 초안 생성 |
| 에뮬레이터 (선택) | `~/Library/Android/sdk/emulator/emulator` |

## 구성

| 파일 | 내용 |
|---|---|
| `SKILL.md` | 5단계 흐름 · `[auto]`/`[human]` 가르는 기준 · hook 등록 |
| `references/scenario-format.md` | `scenario.md` 문법 · 템플릿 · `run.sh` 생성 규칙 |
| `references/result-format.md` | `result.md` 템플릿 |
| `references/summary-format.md` | `summary.md` · `failures.md` 형식 · 결함 분류표 |
| `references/adb-recipes.md` | 기기 · 조작 · 판정 레시피 · 함정 |
| `agents/code-research.md` | 서브에이전트 프롬프트 템플릿 (A1 코드 조사) |
| `scripts/td-lib.sh` | `run.sh` 가 source 하는 공용 함수 |
| `scripts/td-new-run.sh` | run 폴더 생성 |
| `scripts/td-probe.sh` | 화면 요약 · 술어 매칭 확인 |
| `scripts/td-finalize.sh` | run 폴더 접미사 · `result.md` 초안 |
| `hooks/guard-bash.sh` | 포그라운드 `bash run.sh` 차단 · uninstall/`pm clear` 확인 |
| `tests/run-tests.sh` | 스크립트 테스트. `/bin/bash tests/run-tests.sh` · adb 는 `tests/fake-adb` 로 대체 |

## 범위 밖

- 앱 코드 수정. 앱 버그는 보고하고 멈춘다.
- 자료 없는 시나리오 작성. 기대 동작의 출처를 받지 못하면 1단계에서 멈춘다.
- 테스트 코드(Espresso · Robolectric · JUnit) 작성.
- iOS.
