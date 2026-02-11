---
description: 신뢰된 플러그인 자동 설치 관리 (한글: 자동설치, 신뢰설치)
argument-hint: "[on | off | status | check | run]"
allowed-tools: [Read, Bash, AskUserQuestion]
---

# /scout trusted-install - 신뢰된 자동 설치

skills/trusted-install.md를 참조하여 동작합니다.

## 인자: $ARGUMENTS

## 동작 요약

### `on` — Opt-in (활성화)

1. AskUserQuestion으로 사용자 확인:
   ```yaml
   questions:
     - question: "신뢰된 저자(Anthropic 등)의 공식 플러그인을 자동 설치하시겠습니까?"
       header: "Trusted Auto-Install 활성화"
       options:
         - label: "활성화"
           description: "세션 시작 시 새 공식 플러그인을 자동 설치합니다"
         - label: "취소"
           description: "변경하지 않습니다"
       multiSelect: false
   ```
2. 사용자가 "활성화"를 선택하면:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh enable
   ```
3. 활성화 결과를 안내

### `off` — Opt-out (비활성화)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh disable
```

### `status` — 현재 설정 및 마지막 실행 결과

1. config.yaml의 auto_install 설정 표시
2. history.json의 preferences.trustedAutoInstall 상태 표시
3. .last-auto-install.json의 마지막 실행 결과 표시:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh status
   ```

### `check` — 드라이런 (설치 없이 확인)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh check
```

출력:
- 현재 활성/비활성 상태
- 신뢰된 저자 목록
- 설치 후보 플러그인 (설치되지 않은 것만)
- 신규 출시된 플러그인 (이전 캐시 대비)
- 현재 설치된 플러그인 수

### `run` — 즉시 실행 (수동)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh run
```

활성화 상태에서만 동작. 비활성화 상태면 안내 메시지 출력.

## 예시

```
/scout trusted-install on
→ AskUserQuestion으로 확인 후 활성화

/scout trusted-install off
→ 즉시 비활성화

/scout trusted-install status
→ 설정 상태 + 마지막 실행 결과

/scout trusted-install check
→ 설치 후보 목록 표시 (변경 없음)

/scout trusted-install run
→ 누락된 공식 플러그인 설치 실행
```

## 안전 규칙

1. **명시적 opt-in 필수** — `on` 시 반드시 사용자 확인 (AskUserQuestion)
2. **이중 확인** — config.yaml + history.json 둘 다 true여야 동작
3. **신뢰된 저자만** — config.yaml `trusted_authors`에 등록된 저자만 대상
4. **LSP 필터링** — LSP 플러그인은 프로젝트 언어 매칭 시에만 설치
5. **충돌 감지** — 동일 기능 플러그인 중복 설치 방지
6. **오프라인 폴백** — 마켓플레이스 접근 불가 시 캐시 사용, 실패 시 조용히 종료
7. **settings.json 백업** — 설치 전 자동 백업 (plugin-manager.sh)
