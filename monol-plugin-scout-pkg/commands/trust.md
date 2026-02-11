---
description: 신뢰 작성자 관리 (한글: 신뢰, 트러스트)
argument-hint: "[@author | remove @author | list | export]"
allowed-tools: [Read, Bash, AskUserQuestion]
---

# /scout trust — 신뢰 작성자 관리

신뢰 작성자(trusted authors) 목록을 관리합니다. 신뢰 목록에 포함된 작성자의 플러그인은 자동 설치 시 추가 확인 없이 승인됩니다.

## 사용법

```
/scout trust @author          # 신뢰 작성자 추가
/scout trust add @author      # 신뢰 작성자 추가 (명시적)
/scout trust remove @author   # 신뢰 작성자 제거
/scout trust list             # 신뢰 목록 조회
/scout trust export           # 감사 로그 내보내기
```

## 인자: $ARGUMENTS

| 인자 | 설명 |
|------|------|
| `@author` 또는 `add @author` | 해당 작성자를 신뢰 목록에 추가 |
| `remove @author` | 해당 작성자를 신뢰 목록에서 제거 |
| `list` | 현재 신뢰 작성자 전체 목록 표시 |
| `export` | 신뢰 관련 감사 로그를 JSON으로 내보내기 |

## 동작

### Phase 1: 인자 파싱

- `$ARGUMENTS`가 비어 있으면 `list` 서브커맨드로 처리
- `@`로 시작하거나 `add`로 시작하면 추가 흐름
- `remove`로 시작하면 제거 흐름
- `list`, `export`는 해당 서브커맨드 실행

### Phase 2: 추가 (add)

1. `config.yaml`의 `auto_install.trusted_authors` 배열 확인
2. 이미 존재하면 안내 후 종료
3. **AskUserQuestion**으로 사용자에게 확인:
   > "@{author}"을(를) 신뢰 작성자로 추가하시겠습니까? 이 작성자의 플러그인은 자동 설치 시 추가 확인 없이 승인됩니다.
4. 승인 시 `lib/trust-manager.sh add <author>` 실행
5. 결과 출력

### Phase 3: 제거 (remove)

1. "Anthropic"은 보호된 작성자로 제거 불가 → 오류 메시지
2. 존재하지 않으면 안내 후 종료
3. `lib/trust-manager.sh remove <author>` 실행
4. 결과 출력

### Phase 4: 목록 (list)

1. `lib/trust-manager.sh list` 실행
2. 결과를 정리하여 출력

### Phase 5: 감사 내보내기 (export)

1. `lib/trust-manager.sh export` 실행
2. 내보내기 파일 경로를 사용자에게 안내

## 예시

```
# 작성자 추가
/scout trust @vercel
→ "@vercel"을(를) 신뢰 작성자로 추가하시겠습니까? [확인 후 추가]

# 작성자 제거
/scout trust remove @vercel
→ Removed "vercel" from trusted authors.

# 목록 조회
/scout trust list
→ === Trusted Authors ===
     1. Anthropic
     2. vercel

# 감사 로그 내보내기
/scout trust export
→ Audit exported to: data/trust-audit-export.json
```
