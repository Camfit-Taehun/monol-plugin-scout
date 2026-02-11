---
description: 신뢰 작성자 관리 - 자동 설치 신뢰 목록 관리 (한글: 신뢰관리, 트러스트)
argument-hint: "[@author | remove @author | list | export]"
allowed-tools: [Read, Bash, AskUserQuestion]
hooks:
  Stop:
    - hooks:
        - type: command
          command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/track-usage.sh trust"
          timeout: 5
---

# Trust Management — 신뢰 작성자 관리

Scout 플러그인의 자동 설치(auto-install) 기능에서 사용하는 **신뢰 작성자 목록**을 관리하는 스킬입니다.

## 개요

Scout이 MCP 서버 플러그인을 자동으로 설치할 때, 작성자가 신뢰 목록에 포함되어 있으면 추가 확인 없이 설치를 승인합니다. 이를 통해 반복적인 확인 과정을 줄이면서도 보안을 유지할 수 있습니다.

신뢰 목록은 `config.yaml`의 `auto_install.trusted_authors` 배열에 저장되며, 모든 변경 사항은 `data/logs/events.jsonl`에 기록됩니다.

## 서브커맨드

### 추가 — `trust @author` 또는 `trust add @author`

신뢰 작성자를 목록에 추가합니다.

**흐름:**
1. 인자에서 작성자 이름 파싱 (`@` 접두어 자동 제거)
2. 이미 신뢰 목록에 있는지 확인
3. **사용자 확인** (AskUserQuestion): 신뢰 추가의 의미를 설명하고 승인 요청
4. 승인 시 `lib/trust-manager.sh add <author>` 실행
5. `events.jsonl`에 `trust_add` 이벤트 기록

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/trust-manager.sh" add "vercel"
```

### 제거 — `trust remove @author`

신뢰 작성자를 목록에서 제거합니다.

**제한사항:**
- `Anthropic`은 보호된 작성자이며 제거할 수 없습니다.

**흐름:**
1. 보호 작성자 여부 확인
2. 목록에 존재하는지 확인
3. `lib/trust-manager.sh remove <author>` 실행
4. `events.jsonl`에 `trust_remove` 이벤트 기록

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/trust-manager.sh" remove "vercel"
```

### 조회 — `trust list`

현재 신뢰 작성자 전체 목록을 표시합니다.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/trust-manager.sh" list
```

출력 예시:
```
=== Trusted Authors ===
  1. Anthropic
  2. vercel
  3. supabase
```

### 감사 내보내기 — `trust export`

신뢰 관련 전체 감사 로그를 JSON 파일로 내보냅니다.

**수집 대상:**
- `events.jsonl`에서 신뢰 관련 이벤트 (trust_add, trust_remove)
- `history.json`에서 신뢰 기반 자동 설치 로그 (trustedInstallLog)
- 현재 신뢰 작성자 목록

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/trust-manager.sh" export
```

출력 파일: `data/trust-audit-export.json`

```json
{
  "exported_at": "2026-02-12T10:30:00Z",
  "current_trusted_authors": ["Anthropic", "vercel"],
  "trust_events": [...],
  "trusted_install_log": [...]
}
```

## 자동 설치와의 통합

Scout의 `install` 스킬이 MCP 서버를 설치할 때:

1. 서버 메타데이터에서 `author` 필드를 확인
2. `is_trusted(author)` 호출로 신뢰 여부 판단
3. 신뢰 작성자 → 사용자 확인 없이 즉시 설치
4. 비신뢰 작성자 → 사용자에게 설치 확인 요청

이 흐름은 `lib/trust-manager.sh`의 `is_trusted` 함수를 소싱하여 사용합니다:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/trust-manager.sh"
if is_trusted "$author"; then
  # 자동 승인
fi
```

## 보안 고려사항

- **Anthropic은 항상 신뢰**: 기본 보호 작성자로 제거할 수 없습니다.
- **감사 추적**: 모든 신뢰 변경은 `events.jsonl`에 타임스탬프와 함께 기록됩니다.
- **내보내기**: `export` 서브커맨드로 전체 감사 이력을 검토할 수 있습니다.
- **사용자 확인**: 추가 시 반드시 사용자 확인을 거칩니다 (스킬/커맨드 레벨).
