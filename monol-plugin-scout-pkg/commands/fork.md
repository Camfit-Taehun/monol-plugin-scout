---
description: 플러그인 포크 및 커스터마이징
use_when:
  - 사용자가 플러그인을 커스터마이징하고 싶을 때
  - 기존 플러그인을 복사해서 수정하고 싶을 때
---

# /scout fork - 플러그인 포크

플러그인을 복사하여 커스텀 버전을 만듭니다.

## 사용법

```
/scout fork <source-plugin> <new-name>
/scout fork <source-plugin> <new-name> --local
```

## 인자: $ARGUMENTS

## 동작

### 1. 소스 플러그인 확인

- 설치된 플러그인인지 확인
- 마켓플레이스에서 플러그인 위치 조회

### 2. 포크 생성

```bash
# 로컬 플러그인 디렉토리에 복사
.claude/plugins/<new-name>/
├── plugin.json          # 이름 변경
├── agents/              # 원본 복사
├── commands/            # 원본 복사
├── skills/              # 원본 복사
└── FORKED_FROM.txt      # 원본 정보 기록
```

### 3. 메타데이터 업데이트

`plugin.json` 수정:
```json
{
  "name": "<new-name>",
  "version": "1.0.0",
  "forkedFrom": "<source-plugin>",
  "description": "Forked from <source-plugin>",
  "author": "<current-user>"
}
```

### 4. 포크 완료 메시지

```
✅ 플러그인 포크 완료

원본: code-review
새 이름: my-code-review

생성 위치:
.claude/plugins/my-code-review/
├── plugin.json
├── commands/
│   └── review.md
└── FORKED_FROM.txt

다음 단계:
1. 플러그인 파일 수정
2. /plugin reload로 적용
3. /my-code-review로 사용

Tip: overrides/를 사용해 원본을 유지하면서 규칙만 추가할 수도 있습니다.
```

## Override vs Fork

| 방식 | 용도 | 장점 |
|------|------|------|
| Override | 규칙만 추가/수정 | 원본 업데이트 자동 반영 |
| Fork | 전체 커스터마이징 | 완전한 제어 |

Override 예시:
```
overrides/code-review/override.md
→ code-review 플러그인에 추가 규칙 적용
```

## 에러 처리

- **소스 플러그인 없음**:
  ```
  '{source}' 플러그인을 찾을 수 없습니다.
  설치된 플러그인: /plugin list
  ```

- **이름 충돌**:
  ```
  '{new-name}' 플러그인이 이미 존재합니다.
  다른 이름을 사용해주세요.
  ```

## 예시

```
/scout fork code-review my-code-review
→ code-review를 my-code-review로 복사

/scout fork typescript-lsp custom-lsp --local
→ 로컬 전용으로 포크
```
