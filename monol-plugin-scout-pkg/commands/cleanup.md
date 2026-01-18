---
description: 미사용 플러그인 정리 제안
use_when:
  - 사용자가 플러그인 정리를 원할 때
  - 오래된 미사용 플러그인을 찾고 싶을 때
---

# /scout cleanup - 미사용 플러그인 정리

오래된 미사용 플러그인만 정리 제안합니다.

## 사용법

```
/scout cleanup              # 미사용 플러그인 분석 및 정리 제안
/scout cleanup --dry-run    # 정리 대상만 표시 (삭제 안 함)
/scout cleanup --force      # 확인 없이 정리
```

## 인자: $ARGUMENTS

## 동작

### 1. 사용 기록 로드

`.claude/plugins/monol-plugin-scout/data/usage.json`에서 사용 기록 로드:

```json
{
  "plugins": {
    "typescript-lsp": {
      "installed": "2025-12-01",
      "usageCount": 42,
      "lastUsed": "2026-01-18"
    },
    "old-plugin": {
      "installed": "2025-10-01",
      "usageCount": 3,
      "lastUsed": "2025-10-15"
    }
  }
}
```

### 2. 정리 기준 적용

`config.yaml`의 설정 기준:
- `cleanup.unused_days`: 미사용 임계값 (기본 30일)
- `cleanup.low_usage_count`: 저사용 임계값 (기본 3회)

정리 대상:
- 30일 이상 미사용 (lastUsed가 30일 이전)
- 설치 후 한 번도 사용 안 함 (lastUsed가 null이고 설치 후 7일 경과)

### 3. 정리 대상 표시

```
📊 플러그인 정리 제안

오래된 미사용 플러그인이 2개 있습니다:

• plugin-dev
  설치: 2025-11-15 (53일 전)
  마지막 사용: 없음

• old-unused-plugin
  설치: 2025-10-01 (98일 전)
  마지막 사용: 2025-10-15 (84일 전)

나머지 5개 플러그인은 최근 활발히 사용 중입니다. ✓
```

### 4. 인터뷰식 정리

AskUserQuestion으로 정리할 플러그인 선택:

```yaml
questions:
  - question: "정리할 플러그인을 선택하세요"
    header: "정리"
    options:
      - label: "plugin-dev"
        description: "53일간 미사용"
      - label: "old-unused-plugin"
        description: "84일간 미사용"
      - label: "전체 삭제"
        description: "위 플러그인 모두 삭제"
      - label: "취소"
        description: "정리하지 않음"
    multiSelect: true
```

### 5. 정리 실행

선택한 플러그인 제거:
```bash
/plugin uninstall <plugin-name>
```

사용 기록에서도 제거.

## 에러 처리

- **사용 기록 없음**:
  ```
  사용 기록이 없습니다. 플러그인 사용 후 다시 시도해주세요.
  ```

- **정리 대상 없음**:
  ```
  정리할 미사용 플러그인이 없습니다.
  모든 플러그인이 활발히 사용 중입니다. ✓
  ```

## 예시

```
/scout cleanup
→ 미사용 플러그인 분석 및 정리 제안

/scout cleanup --dry-run
→ 정리 대상만 표시 (삭제 안 함)
```
