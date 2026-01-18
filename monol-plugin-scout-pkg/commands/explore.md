---
description: 마켓플레이스 카테고리별 탐색
use_when:
  - 사용자가 마켓플레이스를 둘러보고 싶을 때
  - 특정 카테고리 플러그인을 찾고 싶을 때
---

# /scout explore - 마켓플레이스 탐색

마켓플레이스를 카테고리별로 탐색합니다.

## 사용법

```
/scout explore                    # 전체 카테고리 보기
/scout explore <category>         # 특정 카테고리 탐색
/scout explore --search <keyword> # 키워드 검색
```

## 인자: $ARGUMENTS

## 카테고리

| 카테고리 | 설명 | 예시 플러그인 |
|----------|------|---------------|
| development | 개발 도구 | typescript-lsp, pyright-lsp, feature-dev |
| productivity | 생산성 | commit-commands, code-review |
| security | 보안 | security-guidance |
| testing | 테스트 | playwright |
| external | 외부 서비스 | slack, github, notion, sentry |
| database | 데이터베이스 | firebase, supabase |

## 동작

### 1. 인자 없는 경우 (전체 카테고리)

카테고리 목록과 각 카테고리의 플러그인 수 표시:

```
📦 마켓플레이스 탐색

카테고리를 선택하세요:

• development (12개)
  LSP, 코드 분석, 기능 개발

• productivity (8개)
  커밋, PR, 이슈 관리

• security (3개)
  보안 검사, 경고

• testing (4개)
  E2E, 브라우저 자동화

• external (15개)
  Slack, GitHub, Notion 연동

• database (5개)
  Firebase, Supabase
```

AskUserQuestion으로 카테고리 선택:

```yaml
questions:
  - question: "어떤 카테고리를 탐색할까요?"
    header: "카테고리"
    options:
      - label: "개발 도구"
        description: "12개 플러그인"
      - label: "생산성"
        description: "8개 플러그인"
      - label: "외부 서비스"
        description: "15개 플러그인"
      - label: "전체 보기"
        description: "모든 플러그인"
    multiSelect: false
```

### 2. 카테고리 지정 시

해당 카테고리의 플러그인 목록 표시:

```
📦 development 카테고리 (12개)

| 플러그인 | 점수 | 설명 | 설치 |
|----------|------|------|------|
| typescript-lsp | 84 | TypeScript/JS 코드 인텔리전스 | ✓ |
| feature-dev | 82 | 기능 개발 워크플로우 | - |
| greptile | 78 | AI 기반 코드베이스 검색 | - |
...

설치하려면: /plugin install <name>@<marketplace>
```

### 3. 키워드 검색

`--search` 옵션으로 플러그인 이름/설명 검색:

```
/scout explore --search typescript
→ 'typescript' 포함 플러그인 검색
```

## 예시

```
/scout explore
→ 카테고리 목록 표시

/scout explore development
→ 개발 도구 카테고리 탐색

/scout explore --search slack
→ 'slack' 관련 플러그인 검색
```
