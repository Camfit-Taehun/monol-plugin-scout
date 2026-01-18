---
description: 플러그인 비교표 생성
use_when:
  - 사용자가 플러그인을 비교하고 싶을 때
  - 어떤 플러그인을 선택할지 고민할 때
---

# /scout compare - 플러그인 비교

두 개 이상의 플러그인을 비교표로 보여줍니다.

## 사용법

```
/scout compare <plugin1> <plugin2>
/scout compare <plugin1> <plugin2> <plugin3>
```

## 인자: $ARGUMENTS

## 동작

### 1. 인자 파싱

최소 2개, 최대 4개의 플러그인 이름을 받습니다.

### 2. 플러그인 메타데이터 로드

각 플러그인에 대해:
- 마켓플레이스에서 메타데이터 조회
- 설치 여부 확인 (`enabledPlugins`)
- `plugin-evaluation` 스킬로 점수 계산

### 3. 비교표 생성

```
┌─────────────┬─────────────────┬─────────────────┐
│             │ typescript-lsp  │ pyright-lsp     │
├─────────────┼─────────────────┼─────────────────┤
│ 카테고리    │ development     │ development     │
│ 점수        │ 84              │ 82              │
│ 언어        │ TypeScript/JS   │ Python          │
│ 저자        │ Anthropic       │ Anthropic       │
│ 설치        │ ✓               │ -               │
│ 프로젝트    │ 적합            │ 부적합          │
└─────────────┴─────────────────┴─────────────────┘

추천: 현재 프로젝트(TypeScript)에는 typescript-lsp가 더 적합합니다.
```

### 4. 비교 항목

| 항목 | 설명 |
|------|------|
| 카테고리 | development, productivity, security, testing |
| 종합 점수 | 0-100 |
| 주요 기능 | 플러그인 설명에서 추출 |
| 저자/출처 | 저자 이름 및 소스 타입 |
| 설치 여부 | ✓ / - |
| 프로젝트 적합성 | 현재 프로젝트 컨텍스트 기반 |

### 5. 추천 제시

현재 프로젝트 컨텍스트를 기반으로 어떤 플러그인이 더 적합한지 한 줄 추천.

## 에러 처리

- **플러그인 없음**:
  ```
  '{name}' 플러그인을 찾을 수 없습니다.
  ```

- **동일 플러그인**:
  ```
  같은 플러그인입니다. 다른 플러그인을 선택해주세요.
  ```

- **인자 부족**:
  ```
  비교할 플러그인을 2개 이상 지정해주세요.
  사용법: /scout compare <plugin1> <plugin2>
  ```

## 예시

```
/scout compare typescript-lsp pyright-lsp
→ 두 LSP 플러그인 비교

/scout compare sentry firebase slack
→ 세 외부 서비스 플러그인 비교
```
