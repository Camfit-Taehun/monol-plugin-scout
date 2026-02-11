---
description: 플러그인 마켓플레이스 스캔 및 추천 (한글: 스카우트, 플러그인추천, 플러그인찾기)
argument-hint: "[--quick | --category <cat> | compare | cleanup | explore | audit | fork]"
allowed-tools: [Read, Glob, Grep, Bash, WebFetch, AskUserQuestion]
---

# /scout - 플러그인 마켓플레이스 스캔 및 추천

프로젝트 컨텍스트를 분석하고 호환되는 플러그인을 발견합니다.

## 사용법

```
/scout                    # 프로젝트 분석 후 추천
/scout --quick            # 빠른 스캔 (점수 80+ 만 표시)
/scout --category <cat>   # 특정 카테고리만 스캔
```

## 서브커맨드

```
/scout compare <a> <b>           # 플러그인 비교 → compare.md 참조
/scout cleanup                   # 미사용 플러그인 정리 → cleanup.md 참조
/scout explore [category]        # 마켓플레이스 탐색 → explore.md 참조
/scout audit                     # 보안/업데이트 점검 → audit.md 참조
/scout fork <src> <name>         # 플러그인 포크 → fork.md 참조
/scout trusted-install [on|off|status|check|run]  # 신뢰된 자동 설치 → trusted-install.md 참조
/scout trust [@author|remove|list|export]         # 신뢰 작성자 관리 → trust.md 참조
/scout skills [search|recommend|install|list|combos] # skills.sh 스킬 탐색 → skills.md 참조
```

## 인자: $ARGUMENTS

## 동작

### Phase 1: 프로젝트 컨텍스트 분석

1. **프로젝트 타입 감지**:
   ```
   package.json          → Node.js/JavaScript/TypeScript
   requirements.txt      → Python
   pyproject.toml        → Python (modern)
   Cargo.toml            → Rust
   go.mod                → Go
   pom.xml / build.gradle → Java
   composer.json         → PHP
   Gemfile               → Ruby
   ```

2. **프레임워크 식별** (의존성에서 추출):
   - React, Vue, Angular, Svelte (frontend)
   - Express, Fastify, NestJS (Node backend)
   - FastAPI, Django, Flask (Python)
   - Spring, Quarkus (Java)

3. **설치된 플러그인 확인**:
   - `~/.claude/settings.json`의 `enabledPlugins`
   - `.claude/settings.json`의 프로젝트 플러그인
   - 이미 설치된 플러그인은 추천에서 제외

### Phase 2: 마켓플레이스 스캔

1. **설정된 마켓플레이스 조회**:
   ```bash
   cat ~/.claude/settings.json | grep -A 20 "extraKnownMarketplaces"
   ```

2. **마켓플레이스 메타데이터 로드**:
   - GitHub: `.claude-plugin/marketplace.json` 가져오기
   - 로컬: 디렉토리 구조 읽기
   - 플러그인 정보 파싱 (이름, 설명, 카테고리, 저자)

3. **플러그인 인벤토리 구축**:
   - 플러그인 이름과 버전
   - 카테고리 (development, productivity, security, testing)
   - 저자/조직
   - 소스 타입 (github, git, npm, local)

### Phase 3: 평가 및 점수 계산

`plugin-evaluation` 스킬을 적용하여 종합 점수 계산:

**종합 점수 = (프로젝트 매칭 × 0.4) + (인기도 × 0.3) + (보안 × 0.3)**

#### 프로젝트 매칭 (40%)
| 기준 | 점수 |
|------|------|
| 언어 정확 매칭 | 30 |
| 프레임워크 호환성 | 25 |
| 카테고리 관련성 | 20 |
| 의존성 호환성 | 15 |
| 아키텍처 적합성 | 10 |

#### 인기도 (30%)
| 기준 | 점수 |
|------|------|
| GitHub 스타 (10k+: 30, 1k+: 25, 100+: 15) | 0-30 |
| 최근 커밋 (90일) | 0-20 |
| 업데이트 최신성 | 0-20 |
| 이슈 응답 건강도 | 0-15 |
| 포크 활동 | 0-15 |

#### 보안 (30%)
| 기준 | 점수 |
|------|------|
| 라이선스 (MIT/Apache: 30, GPL: 20, Unknown: 0) | 0-30 |
| 알려진 취약점 | 0-40 |
| 저자 평판 (Official: 30, Verified: 20) | 0-30 |

### Phase 4: 추천 제시

추천 결과를 다음 형식으로 출력:

```markdown
## Plugin Scout Report

**프로젝트**: [감지된 언어] + [프레임워크]
**설치된 플러그인**: [개수] ([목록])

### 추천 플러그인

#### 1. [plugin-name] (점수: XX/100)
**추천 이유**: [프로젝트 컨텍스트 기반 설명]

| 지표 | 점수 | 상세 |
|------|------|------|
| 프로젝트 매칭 | XX | [이유] |
| 인기도 | XX | [스타, 활동] |
| 보안 | XX | [라이선스, 저자] |

**설치**: `/plugin install [name]@[marketplace]`

---

[상위 3-5개 플러그인 반복]
```

### 인터뷰식 설치

AskUserQuestion 도구를 사용해 대화형으로 설치:

```yaml
questions:
  - question: "어떤 종류의 플러그인을 찾으시나요?"
    header: "카테고리"
    options:
      - label: "개발 도구"
        description: "LSP, 코드 분석, 기능 개발"
      - label: "생산성"
        description: "커밋, PR, 이슈 관리"
      - label: "외부 서비스"
        description: "Slack, GitHub, Notion 연동"
      - label: "전체 스캔"
        description: "프로젝트 분석 후 맞춤 추천"
    multiSelect: false
```

설치 선택 시 `multiSelect: true`로 복수 선택 가능하게.

## 안전 규칙

1. **자동 설치 금지** - 항상 사용자 동의 필요
2. **보안 경고 표시**:
   - 알 수 없거나 제한적인 라이선스
   - 1년 이상 업데이트 없음
   - 검증되지 않은 저자
   - 알려진 취약점
3. **설치 전 확인** - 설치 명령 반복 후 승인 대기

## 보안 경고 형식

```markdown
**보안 경고**: [plugin-name]
- 라이선스: [type] - [영향]
- 마지막 업데이트: [date] - [우려 사항]
- 저자: [name] - [검증 상태]
- 취약점: [status]

주의해서 진행하세요. 신뢰하는 소스만 설치하세요.
```

## 에러 처리

- **마켓플레이스 없음**:
  ```
  설정된 마켓플레이스가 없습니다. 추가하세요:
  /plugin marketplace add anthropics/claude-code-plugins
  ```

- **네트워크 에러**: 캐시된 데이터 사용, 문제 보고

- **프로젝트 감지 실패**:
  ```
  프로젝트 타입을 감지할 수 없습니다.
  어떤 언어/프레임워크를 사용하시나요?
  ```

## 예시

```
/scout
→ 프로젝트 분석 후 맞춤 플러그인 추천

/scout --quick
→ 점수 80점 이상 플러그인만 빠르게 표시

/scout --category development
→ 개발 도구 카테고리만 스캔
```
