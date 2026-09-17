# result.md 형식

실행 1회 = `result.md` 1개. `runs/<run 폴더>/result.md` 에 둔다.

`td-finalize.sh` 가 초안을 만든다. agent 는 `<채움>` 을 채우고 `## 다음` 을 쓴다.

## 템플릿

```markdown
# SplashActivity 크래시 재현 — 001_S01-S02_FAIL-1_실행불가-1

## 실행
| 항목 | 값 |
|---|---|
| 시각 | 2026-09-15 16:20:03 ~ 16:25:41 |
| 기기 | S25 `R3CXXXXXXXX` (Android 16 / One UI 8.5) |
| 빌드 | 구버전 = debug · 신버전 = release(minify) |
| 시나리오 | `scenario.md` (수정 2026-09-15 16:05) |
| 근거 자료 | Crashlytics `a1b2c3d4` 스택 — 사용자 제출 2026-09-15 |
| 로그 | `run.log` |

## 판정
| # | 시나리오 | 결과 | 근거 |
|---|---|---|---|
| 1 | 알림 콜드스타트 task 재실행 | FAIL | `PASS  1.8 크래시가 발생한다`<br>`FAIL  1.9 스택이 SplashActivity 를 가리킨다` |
| 2 | 재실행 후 홈으로 돌아간다 | 실행불가 | 의존 S01 FAIL |

PASS 0 / FAIL 1 / 중단 0 / 실행불가 1 / 건너뜀 0

## 실패 상세
### S01.9_check
- 결함: 기준 결함
- 원인: `evidence/s1-crash.txt` 에 스택이 난독화된 이름(`a.b.c`)으로 남았다. 기준이 원래 클래스명을 찾았다.
- 캡처: `fail/S01.9_check.png` · `fail/S01.9_check.xml`

## 다음
- `scenario.md` 시나리오 1 스텝 9 의 기준을 mapping 된 이름으로 고친다. 사용자 확인 후 재실행한다.
```

## 칸

| 칸 | 채우는 것 | 값 |
|---|---|---|
| 제목 | agent | `# <scenario.md 첫 줄에서 "# " 를 뺀 값> — <run 폴더 이름>`. `td-finalize.sh` 가 `— <run 폴더 이름>` 까지 채운다 |
| 시각 · 로그 | `td-finalize.sh` | 첫 · 마지막 로그 시각. 날짜는 `run.log` 수정일이다 |
| 기기 · 빌드 · 시나리오 · 근거 자료 | agent | `scenario.md` 의 `## 대상` |
| 판정 표 | `td-finalize.sh` | `td_summary` 상태 · 시나리오별 `PASS  ` / `FAIL  ` 원문 줄 · 사유 |
| 실패 상세 절 | `td-finalize.sh` | `fail/` 의 캡처마다 한 절 |
| 결함 | agent | 결함 분류 6종 중 하나 |
| 원인 | agent | 한 문장. 로그 · 캡처 원문을 인용한다 |
| 다음 | agent | 재실행 계획 또는 보고 내용 |

## 결함 분류

`앱 버그` · `스크립트 결함` · `기준 결함` · `사람 진행 오류` · `연쇄` · `미결` 중 하나를 쓴다. 판정 근거와 다음 행동은 `references/summary-format.md` 의 결함 분류표를 따른다.

- `연쇄` 는 원인 칸에 원 실패 SID 를 쓴다.
- `미결` 은 원인 칸에 `미결: <질문> / 답할 사람: <누구>` 로 쓴다.
- 캡처는 `fail/<SID>_<종류>.png` · `.xml` 이다. 종류는 `step` · `check` 다.
- `failures.md` 의 `human` 행은 캡처가 없다. `실패 상세` 절도 생기지 않으므로 agent 가 `### <SID>_human` 절을 추가하고 캡처 칸에 `-` 를 쓴다.

## 규칙

- **실행 직후 판정만 쓴다.** 뒤 run 에서 분류가 바뀌어도 `result.md` 를 고치지 않는다. 재판정은 `summary.md` · `failures.md` 에만 쓴다.
- `## 판정` 의 `근거` 칸은 로그 원문이다. 요약하지 않는다.
- 결함 · 원인은 `failures.md` 의 같은 캡처 행과 일치시킨다.
- 실패가 없으면 `실패 상세` 절이 생기지 않는다.
- 앱 버그를 고치지 않는다. `다음` 에 무엇을 보고했는지만 쓴다.
- 배경 설명·총평을 쓰지 않는다.
