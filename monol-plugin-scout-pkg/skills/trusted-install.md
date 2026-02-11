---
description: 신뢰된 플러그인 자동 설치 - Anthropic 공식 플러그인 자동 설치 관리 (한글: 자동설치, 신뢰설치)
argument-hint: "[on | off | status | check | run]"
allowed-tools: [Read, Bash, AskUserQuestion]
hooks:
  Stop:
    - hooks:
        - type: command
          command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/track-usage.sh trusted-install"
          timeout: 5
---

# /scout trusted-install - 신뢰된 플러그인 자동 설치

Anthropic 등 신뢰된 저자의 공식 플러그인을 자동으로 설치하고 관리합니다.

## 사용법

```
/scout trusted-install on       # 자동 설치 활성화 (opt-in)
/scout trusted-install off      # 자동 설치 비활성화 (opt-out)
/scout trusted-install status   # 현재 설정 + 마지막 실행 결과
/scout trusted-install check    # 드라이런: 무엇이 설치될지 미리 확인
/scout trusted-install run      # 즉시 실행 (수동 트리거)
```

## 인자: $ARGUMENTS

## 개요

Trusted Auto-Install은 공식 마켓플레이스에 등록된 신뢰된 저자의 플러그인을 자동으로 감지하고 설치하는 기능입니다. 수동으로 마켓플레이스를 탐색하지 않아도 새 공식 플러그인이 출시되면 자동으로 환경에 반영됩니다.

**핵심 원칙:**
- 사용자의 **명시적 opt-in** 없이는 동작하지 않습니다
- config.yaml과 history.json **이중 확인**으로 우발적 실행을 방지합니다
- 설치 대상은 **trusted_authors** 목록에 등록된 저자(기본: Anthropic)만 해당합니다

## 동작

### Subcommand: `on` (활성화)

1. **사용자 확인** (AskUserQuestion):
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
   - config.yaml `auto_install.enabled` → `true`
   - history.json `preferences.trustedAutoInstall` → `true`

3. 결과 안내:
   ```markdown
   ## Trusted Auto-Install 활성화됨

   신뢰된 저자: Anthropic
   마켓플레이스: claude-plugins-official

   다음 세션 시작 시 자동으로 새 공식 플러그인을 확인하고 설치합니다.
   `/scout trusted-install check`로 미리 확인할 수 있습니다.
   ```

### Subcommand: `off` (비활성화)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh disable
```

결과 안내:
```markdown
## Trusted Auto-Install 비활성화됨

자동 설치가 중지되었습니다.
`/scout trusted-install on`으로 다시 활성화할 수 있습니다.
```

### Subcommand: `status` (상태 확인)

1. config.yaml 설정 읽기:
   ```bash
   cat ${CLAUDE_PLUGIN_ROOT}/config.yaml
   ```
   `auto_install` 섹션의 설정을 표시합니다.

2. 마지막 실행 결과 표시:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh status
   ```

3. 출력 형식:
   ```markdown
   ## Trusted Auto-Install 상태

   | 항목 | 값 |
   |------|------|
   | 활성화 (config) | true / false |
   | 활성화 (history) | true / false |
   | 신뢰된 저자 | Anthropic |
   | LSP 언어 필터 | true |
   | 충돌 감지 | true |

   ### 마지막 실행
   - 시간: 2026-02-12T10:30:00Z
   - 설치됨: 2개
   - 건너뜀: 1개
   - 신규 출시: 0개
   - 오류: 0개
   ```

### Subcommand: `check` (드라이런)

설치 없이 무엇이 설치될지 미리 확인합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh check
```

출력에 포함되는 정보:
- 현재 활성/비활성 상태
- 신뢰된 저자 목록
- **설치 후보**: 마켓플레이스에 있지만 아직 설치되지 않은 플러그인
- **신규 출시**: 이전 캐시 대비 새로 추가된 플러그인
- 현재 설치된 플러그인 수

### Subcommand: `run` (즉시 실행)

활성화 상태에서 즉시 자동 설치를 실행합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/trusted-installer.sh run
```

**실행 파이프라인:**

1. `is_enabled()` 확인 → 비활성화면 안내 후 종료
2. 캐시 디렉토리 생성 (`$DATA_DIR/.cache/`)
3. `detect_new_releases()` — 이전 캐시와 현재 마켓플레이스 비교
4. `filter_relevant()` — 설치 후보 필터링
   - 마켓플레이스에서 신뢰된 저자의 플러그인 추출
   - 이미 설치된 플러그인 제외
   - LSP 언어 필터 적용 (프로젝트와 무관한 LSP 제외)
   - 충돌 감지 (동일 기능 플러그인 중복 방지)
5. 후보별 `execute_install()` + `record_install()`
6. `write_install_report()` → `.last-auto-install.json` 저장
7. 로거에 요약 기록

## 안전 메커니즘

### 이중 확인 (Dual-Gate)

자동 설치가 동작하려면 두 곳 모두 `true`여야 합니다:

| 위치 | 키 | 설명 |
|------|-----|------|
| config.yaml | `auto_install.enabled` | 설정 파일 레벨 |
| history.json | `preferences.trustedAutoInstall` | 사용자 선호 레벨 |

어느 한 쪽이라도 `false`이면 자동 설치가 실행되지 않습니다.

### LSP 언어 필터링

`lsp_language_filter: true` 설정 시, LSP 플러그인은 현재 프로젝트의 언어와 매칭될 때만 설치됩니다.

| LSP 플러그인 | 매칭 조건 |
|-------------|----------|
| typescript-lsp | package.json 또는 tsconfig.json 존재 |
| pyright-lsp | requirements.txt, pyproject.toml, setup.py 존재 |
| gopls-lsp | go.mod 존재 |
| rust-analyzer-lsp | Cargo.toml 존재 |
| jdtls-lsp | pom.xml 또는 build.gradle 존재 |
| php-lsp | composer.json 존재 |
| clangd-lsp | *.c, *.cpp, *.h 파일 존재 |
| swift-lsp | *.swift 파일 존재 |
| kotlin-lsp | *.kt, *.kts 파일 존재 |
| csharp-lsp | *.cs 파일 존재 |
| lua-lsp | *.lua 파일 존재 |

LSP가 아닌 일반 플러그인은 항상 매칭됩니다 (필터링 없음).

### 충돌 감지

`check_conflicts: true` 설정 시, 동일 기능 그룹 내 플러그인이 이미 설치되어 있으면 새 플러그인 설치를 건너뜁니다.

| 그룹 | 포함 플러그인 |
|------|-------------|
| formatters | prettier-format, eslint-fix, biome-format |
| linters | eslint-lsp, biome-lsp |
| git | commit-commands, git-helper, conventional-commits |

### 신규 출시 감지

`detect_new_releases: true` 설정 시, 이전에 캐시된 마켓플레이스 카탈로그와 현재를 비교하여 새로 추가된 플러그인을 감지합니다. 감지 결과는 `check` 및 `run` 실행 시 리포트에 포함됩니다.

### 오프라인 폴백

마켓플레이스 파일에 접근할 수 없는 경우:
1. 로컬 캐시 (`$DATA_DIR/.cache/trusted-catalog.json`) 사용
2. 캐시도 없으면 조용히 종료 (에러 없음)

### 설치 리포트

모든 `run` 실행 후 `$DATA_DIR/.last-auto-install.json`에 결과가 기록됩니다:

```json
{
  "timestamp": "2026-02-12T10:30:00Z",
  "installed": ["plugin-a", "plugin-b"],
  "skipped": [],
  "newReleases": [],
  "errors": [],
  "summary": "Installed 2, Skipped 0, New 0"
}
```

## 설정 (config.yaml)

```yaml
auto_install:
  enabled: false                # /scout trusted-install on 으로 opt-in
  trusted_authors: ["Anthropic"]
  marketplace: "claude-plugins-official"
  lsp_language_filter: true     # LSP는 프로젝트 언어 매칭 필요
  scope: "user"
  cache_catalog: true           # marketplace 카탈로그 로컬 캐시
  cache_ttl: 86400              # 24시간
  detect_new_releases: true     # 이전 vs 현재 비교
  check_conflicts: true         # 동일 기능 플러그인 감지
```

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

## 관련 명령어

- `/scout install` — 수동 플러그인 설치
- `/scout uninstall` — 플러그인 제거
- `/scout explore` — 마켓플레이스 탐색
- `/scout audit` — 플러그인 보안 감사
