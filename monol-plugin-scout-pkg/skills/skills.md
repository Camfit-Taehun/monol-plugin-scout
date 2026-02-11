---
description: skills.sh 스킬 스카우트 - 스킬 탐색, 추천, 설치 (한글: 스킬찾기, 스킬추천, 스킬설치)
argument-hint: "[search <query> | recommend | install <id> | list | combos]"
allowed-tools: [Read, Bash, WebFetch, AskUserQuestion]
hooks:
  Stop:
    - hooks:
        - type: command
          command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/track-usage.sh skills"
          timeout: 5
---

# /scout skills - skills.sh 스킬 스카우트

## skills.sh란?

[skills.sh](https://skills.sh)는 Claude Code용 커뮤니티 스킬 마켓플레이스입니다.
스킬(skill)은 Claude Code의 기능을 확장하는 가벼운 모듈로, 플러그인보다 단순하고 빠르게 설치할 수 있습니다.

스킬 스카우트는 skills.sh에서 프로젝트에 적합한 스킬을 발견하고 추천합니다.

## 사용법

```
/scout skills                     # 상태 표시
/scout skills search <query>      # 키워드 검색
/scout skills recommend           # 맞춤 추천
/scout skills install <id>        # 스킬 설치
/scout skills list                # 설치 목록
/scout skills combos              # 시너지 추천
```

## 인자: $ARGUMENTS

## 동작

### Phase 1: 카탈로그 동기화

skills.sh API에서 전체 스킬 카탈로그를 가져옵니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh fetch
```

**API 동작:**
- `GET https://skills.sh/api/skills?limit=500&offset=0` 호출
- `hasMore` 플래그로 페이지네이션 (0.1초 간격)
- 결과를 `data/.cache/skills-catalog.json`에 캐시
- 캐시 TTL: config.yaml `skills_sh.cache_ttl` (기본 3600초)
- 네트워크 실패 시: 캐시가 있으면 캐시 반환, 없으면 빈 배열

### Phase 2: Anthropic 공식 스킬 자동 설치

Anthropic이 공식 제공하는 스킬은 사용자 확인 없이 자동 설치합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh auto
```

**판별 기준:**
- `topSource === "anthropics/skills"` 인 스킬만 대상
- config.yaml `skills_sh.auto_install_official: true` 일 때만 동작
- npx 사전 확인 (`check_npx`)

**설치 방법:**
- `npx skills add <skill-id>` 실행
- `~/.claude/skills/` 디렉토리에 설치됨
- 설치 결과를 `data/.last-skill-install.json`에 기록
- `data/history.json`의 `skills.installed`에 이력 저장

**세션 시작 시 자동 실행:**
이 기능은 on-session-start 훅에서 호출되어 매 세션마다 새 공식 스킬을 자동으로 설치합니다.

### Phase 3: 추천 (커뮤니티 스킬)

미설치 스킬을 점수 기반으로 평가하여 추천합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh recommend 5
```

**점수 산출 방식 (0-100점):**

#### 인기도 (50% 가중치)

스킬의 설치 수(installs/downloads)를 기준으로 정규화합니다.

| 설치 수 | 점수 |
|---------|------|
| 1000+ | 100 |
| 500+ | 80 |
| 100+ | 60 |
| 50+ | 40 |
| 10+ | 20 |
| 10 미만 | 10 |

#### 프로젝트 매칭 (30% 가중치)

`lib/project-analyzer.sh types`의 결과와 스킬의 이름/태그/설명을 비교합니다.
매칭 횟수에 비례하여 점수 부여 (최대 100점).

#### 소스 신뢰도 (20% 가중치)

| 소스 | 점수 |
|------|------|
| `anthropics/*` | 100 |
| `verified/*`, `official/*` | 70 |
| 커뮤니티 (기타) | 40 |

**추천 흐름:**
1. 카탈로그 fetch (캐시 활용)
2. 설치된 스킬 제외
3. 각 스킬 점수 계산
4. 점수 내림차순 정렬
5. 상위 N개 반환 (config.yaml `skills_sh.max_recommendations`)
6. AskUserQuestion (multiSelect)으로 설치 선택

```yaml
questions:
  - question: "추천된 스킬 중 설치할 것을 선택하세요:"
    header: "스킬 추천"
    options:
      - label: "<skill-name> (점수: XX/100)"
        description: "<skill-description>"
    multiSelect: true
```

선택된 각 스킬에 대해:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh install <skill-id>
```

### Phase 4: 키워드 검색

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh search "<query>"
```

카탈로그에서 이름, 태그, 설명을 대소문자 무시로 검색합니다.
매칭된 결과는 점수순으로 정렬됩니다.

### Phase 5: 시너지 콤보 추천

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh combos
```

설치된 플러그인(`~/.claude/settings.json`의 `enabledPlugins`)을 기반으로
보완적인 스킬을 추천합니다.

**콤보 매핑:**

| 설치된 플러그인 키워드 | 추천 스킬 키워드 |
|----------------------|----------------|
| typescript-lsp | typescript-strict, type-coverage, ts-refactor |
| code-review | pr-description, review-checklist |
| commit-commands | conventional-commits, changelog-gen |
| sentry | error-tracking, alert-config |
| react | react-patterns, component-gen |
| testing | test-gen, coverage-report |

카탈로그에서 추천 스킬 키워드와 매칭되는 실제 스킬을 찾아
`_reason` (시너지 이유)과 함께 반환합니다.

## 상태 확인

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh status
```

표시 항목:
- 설치된 스킬 수 + 목록
- 마지막 동기화 시각 (캐시 파일 mtime)
- skills_sh 설정 요약 (enabled, auto_install_official, cache_ttl, max_recommendations)
- 마지막 자동 설치 결과 (`.last-skill-install.json`)

## 안전 규칙

1. **Anthropic 공식만 자동 설치**
   - `topSource: "anthropics/skills"` 인 스킬만 사용자 확인 없이 설치
   - 커뮤니티 스킬은 반드시 AskUserQuestion으로 동의 후 설치

2. **npx 사전 확인**
   - 스킬 설치 전 `command -v npx` 확인
   - npx 미설치 시 Node.js 설치 방법 안내 메시지 출력

3. **네트워크 안전**
   - curl --max-time 10 제한
   - API 실패 시 캐시 폴백
   - 캐시도 없으면 빈 배열 반환 (에러로 중단하지 않음)

4. **이력 추적**
   - 모든 설치를 history.json에 기록
   - 자동 설치 결과를 .last-skill-install.json에 기록
   - 설치 소스 (auto/manual) 구분

5. **설정 존중**
   - config.yaml `skills_sh` 섹션의 설정값 우선
   - `enabled: false`이면 전체 비활성
   - `auto_install_official: false`이면 자동 설치 비활성

## 예시

```
/scout skills
→ 설치된 스킬 현황과 상태 표시

/scout skills search typescript
→ "typescript" 관련 스킬 검색 (이름/태그/설명 매칭)

/scout skills recommend
→ 프로젝트 분석 기반 맞춤 추천, multiSelect로 설치

/scout skills install conventional-commits
→ npx skills add conventional-commits 실행

/scout skills combos
→ 설치된 플러그인 기반 시너지 스킬 추천

/scout skills list
→ ~/.claude/skills/ + 플러그인 스킬 목록
```

## 에러 처리

- **npx 없음**: Node.js 설치 안내 출력
- **네트워크 실패**: 캐시 폴백 → 빈 결과 반환
- **빈 카탈로그**: 추천 없이 빈 배열 반환
- **설치 실패**: 에러 메시지 출력, 다른 스킬 설치는 계속 진행
- **config.yaml 없음**: 모든 설정 기본값 사용
