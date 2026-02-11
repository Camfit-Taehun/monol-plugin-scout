---
description: skills.sh 스킬 탐색 및 설치 (한글: 스킬, 스킬찾기, 스킬스카우트)
argument-hint: "[search <query> | recommend | install <id> | list | combos]"
allowed-tools: [Read, Bash, WebFetch, AskUserQuestion]
---

# /scout skills - skills.sh 스킬 탐색 및 설치

skills.sh 마켓플레이스에서 스킬을 탐색, 추천, 설치합니다.

## 사용법

```
/scout skills                     # 설치된 스킬 + 상태 표시
/scout skills search <query>      # 키워드로 스킬 검색
/scout skills recommend           # 프로젝트 기반 맞춤 추천
/scout skills install <id>        # 스킬 설치
/scout skills list                # 설치된 스킬 목록
/scout skills combos              # 시너지 콤보 추천
```

## 인자: $ARGUMENTS

## 동작

### Phase 1: 카탈로그 동기화

skills.sh API에서 스킬 카탈로그를 가져옵니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh fetch
```

- 캐시 TTL 내이면 로컬 캐시 사용 (기본 1시간)
- 네트워크 실패 시 캐시 폴백, 캐시 없으면 빈 배열 반환

### Phase 2: Anthropic 공식 스킬 자동 설치

`topSource: "anthropics/skills"` 인 스킬은 사용자 확인 없이 자동 설치합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh auto
```

- config.yaml `skills_sh.auto_install_official: true` 일 때만 동작
- 이미 설치된 스킬은 건너뜀
- 설치 결과를 `.last-skill-install.json`에 기록

### Phase 3: 커뮤니티 스킬 추천

미설치 커뮤니티 스킬을 점수로 평가하여 추천합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh recommend 5
```

**점수 계산 (0-100)**:

| 가중치 | 요소 | 설명 |
|--------|------|------|
| 50% | 인기도 (installs) | 설치 수 기반 정규화 |
| 30% | 프로젝트 매칭 | 이름/태그 vs 프로젝트 언어/프레임워크 |
| 20% | 소스 신뢰도 | anthropics/* = 100, verified = 70, community = 40 |

AskUserQuestion으로 multiSelect 제시:

```yaml
questions:
  - question: "추천된 스킬 중 설치할 것을 선택하세요:"
    header: "스킬 추천"
    options:
      - label: "<skill-name> (점수: XX)"
        description: "<description>"
      # ... 추천된 스킬 목록
    multiSelect: true
```

선택된 스킬에 대해 `lib/skill-scout.sh install <id>` 실행.

### Phase 4: 시너지 콤보 추천

설치된 플러그인 기반으로 보완 스킬을 추천합니다.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh combos
```

콤보 매핑:

| 설치된 플러그인 | 추천 스킬 |
|----------------|----------|
| typescript-lsp | typescript-strict, type-coverage, ts-refactor |
| code-review | pr-description, review-checklist |
| commit-commands | conventional-commits, changelog-gen |
| sentry | error-tracking, alert-config |
| react 관련 | react-patterns, component-gen |
| testing 관련 | test-gen, coverage-report |

## 서브커맨드 상세

### search <query>

키워드로 스킬을 검색합니다. 이름, 태그, 설명에서 대소문자 무시 매칭.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh search "$query"
```

결과를 점수순으로 정렬하여 표시.

### recommend

프로젝트 컨텍스트를 분석하여 맞춤 추천. `lib/project-analyzer.sh types`로 프로젝트 타입 감지.

### install <id>

특정 스킬을 `npx skills add <id>`로 설치.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh install "$id"
```

### list

설치된 스킬 목록과 상태를 표시.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-scout.sh status
```

### combos

설치된 플러그인 기반 시너지 스킬 추천.

## 예시

```
/scout skills
→ 설치된 스킬 현황 + 상태 표시

/scout skills search typescript
→ "typescript" 키워드로 스킬 검색

/scout skills recommend
→ 프로젝트 분석 후 맞춤 스킬 추천 (multiSelect)

/scout skills install conventional-commits
→ conventional-commits 스킬 설치

/scout skills combos
→ 설치된 플러그인 기반 시너지 추천
```

## 안전 규칙

1. **Anthropic 공식만 자동 설치** - `topSource: "anthropics/skills"` 스킬만 무확인 설치
2. **커뮤니티 스킬은 확인 필요** - AskUserQuestion으로 사용자 동의 후 설치
3. **npx 사전 확인** - npx 미설치 시 설치 방법 안내
4. **네트워크 실패 안전** - 캐시 폴백, 빈 결과 반환 (에러로 중단하지 않음)
5. **설치 이력 기록** - history.json에 모든 설치 이력 저장
