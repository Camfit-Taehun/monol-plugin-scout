# Plugin Scout - 작업 완료 후 추천 체크 (v2.1)

작업이 완료되었습니다. 아래 절차에 따라 플러그인 추천 여부를 결정하세요.

## 1단계: 추천 제한 확인 (필수)

먼저 recommendation-controller를 통해 추천 가능 여부를 확인합니다:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/recommendation-controller.sh can-recommend session
```

결과 해석:
- `true` → 추천 가능, 2단계로 진행
- `blocked:quiet_mode` → 무음 모드 활성화됨, 추천 중단
- `blocked:session_limit` → 세션 추천 한도 도달, 추천 중단
- `blocked:daily_limit` → 일일 추천 한도 도달, 추천 중단

**중요**: `blocked:`로 시작하면 즉시 중단하고 아무것도 출력하지 마세요.

## 2단계: 스마트 타이밍 확인

이벤트 기반 추천이 설정된 경우:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/recommendation-controller.sh timing task-complete
```

결과 해석:
- `true` → 타이밍 조건 충족, 3단계로 진행
- `blocked:not_after_commit` → 커밋 후에만 추천 설정됨, 추천 중단
- `blocked:not_after_pr` → PR 후에만 추천 설정됨, 추천 중단

## 3단계: 추천 조건 검증

다음 조건이 모두 충족되어야 추천:

1. **의미 있는 작업 완료** - 단순 질문/답변이 아닌 코드 작성, 파일 수정 등
2. **프로젝트 컨텍스트 존재** - package.json, pyproject.toml 등 감지됨
3. **플러그인 관련 작업 중이 아님** - `/scout`, 플러그인 설치 등 진행 중이 아님

## 4단계: 추천 실행

조건 충족 시 간단히 제안:

```
💡 이 프로젝트에 [plugin-name] 플러그인이 도움될 수 있어요.
   [한 줄 설명]
   관심있으시면 `/scout`로 더 알아보세요.
```

## 5단계: 추천 기록

추천 후 반드시 기록:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/recommendation-controller.sh record 1 post-task
```

## 설정 변경 안내

사용자가 추천 빈도에 불만을 표시하면:

- **완전 중단**: `/scout quiet on`
- **빈도 조절**: `/scout frequency session 2` 또는 `/scout frequency daily 5`
- **타이밍 변경**: `/scout timing after-commit on`

## 현재 상태 확인

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/recommendation-controller.sh status
```

## 추천 안 하는 경우

- recommendation-controller가 `blocked:*` 반환
- 단순 질문/답변 세션
- 프로젝트 파일이 없음
- 사용자가 플러그인 관련 작업 중
