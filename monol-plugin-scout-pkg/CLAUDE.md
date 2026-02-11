# Plugin Scout v4.1

Claude Code 플러그인 마켓플레이스 모니터링 및 추천 에이전트

## v4.1 새 기능

### 신뢰된 자동 설치 (`/scout trusted-install`)
Anthropic 공식 플러그인을 세션 시작 시 자동 설치합니다 (opt-in).
```bash
/scout trusted-install on      # 자동 설치 활성화 (사용자 확인 필요)
/scout trusted-install off     # 비활성화
/scout trusted-install status  # 현재 설정 + 마지막 결과
/scout trusted-install check   # 미설치 공식 플러그인 목록 (dry-run)
/scout trusted-install run     # 수동 즉시 실행
```

**안전 장치:**
- opt-in 필수 (기본 비활성화)
- LSP 플러그인은 프로젝트 언어 매칭 필요
- 동일 기능 플러그인 충돌 감지
- 신규 출시 감지 및 알림
- 오프라인 시 캐시 폴백

### 신뢰 작성자 관리 (`/scout trust`)
자동 설치 대상 작성자를 관리합니다.
```bash
/scout trust @vercel           # 신뢰 작성자 추가
/scout trust remove @vercel    # 신뢰 작성자 제거
/scout trust list              # 신뢰 목록 표시
/scout trust export            # 감사 로그 JSON 내보내기
```

### skills.sh 스킬 스카우트 (`/scout skills`)
skills.sh에서 스킬을 탐색하고 추천합니다.
```bash
/scout skills search <query>   # 키워드 검색
/scout skills recommend        # 프로젝트 맞춤 추천
/scout skills install <id>     # 스킬 설치
/scout skills list             # 설치된 스킬 목록
/scout skills combos           # 플러그인 기반 시너지 추천
```

**Anthropic 공식 스킬**: `topSource: "anthropics/skills"`인 스킬은 자동 설치 (동의 불필요).

## 이전 버전 기능

### 무음 모드 (`/scout quiet`)
추천 알림을 완전히 비활성화합니다.
```bash
/scout quiet on     # 무음 모드 활성화
/scout quiet off    # 무음 모드 비활성화
/scout quiet        # 현재 상태 확인
```

### 추천 빈도 조절 (`/scout frequency`)
세션당/일일 추천 횟수를 제한합니다.
```bash
/scout frequency session 2   # 세션당 최대 2회
/scout frequency daily 5     # 하루 최대 5회
/scout frequency cooldown 60 # 추천 간격 60분
```

### 스마트 타이밍 (`/scout timing`)
특정 이벤트 후에만 추천하도록 설정합니다.
```bash
/scout timing after-commit on  # 커밋 후에만 추천
/scout timing after-pr on      # PR 후에만 추천
/scout timing always           # 항상 추천 (기본값)
```

## 설치 (Claude Code 플러그인)

```bash
# 1. 레포 클론
git clone https://github.com/your/monol-plugin-scout.git ~/monol-plugin-scout

# 2. ~/.claude/settings.json에 마켓플레이스 등록
```

`~/.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "monol-plugin-scout": {
      "source": {
        "source": "directory",
        "path": "~/monol-plugin-scout/.claude/plugins"
      }
    }
  },
  "enabledPlugins": {
    "monol-plugin-scout@monol-plugin-scout": true
  }
}
```

플러그인 활성화 후:
- 프로젝트 분석 후 맞춤 플러그인 추천

## 스킬 (Commands)

| 커맨드 | 한글 키워드 | 설명 |
|--------|-------------|------|
| `/scout` | 스카우트, 플러그인추천 | 플러그인 추천 |
| `/scout trusted-install` | 자동설치, 신뢰설치 | 신뢰된 자동 설치 (v4.1) |
| `/scout trust` | 신뢰, 트러스트 | 신뢰 작성자 관리 (v4.1) |
| `/scout skills` | 스킬, 스킬찾기 | skills.sh 스킬 탐색 (v4.1) |
| `/scout quiet` | 무음, 조용히 | 무음 모드 설정 |
| `/scout frequency` | 빈도, 횟수 | 추천 빈도 설정 |
| `/scout timing` | 타이밍, 추천시점 | 스마트 타이밍 |
| `/compare` | 비교, 플러그인비교 | 플러그인 비교 |
| `/cleanup` | 정리, 플러그인정리 | 미사용 정리 |
| `/explore` | 탐색, 마켓플레이스 | 카테고리 탐색 |
| `/audit` | 점검, 보안점검 | 보안/업데이트 점검 |
| `/fork` | 포크, 복사 | 플러그인 포크 |

**한글 자연어 입력 지원**: "플러그인 추천해줘", "보안 점검해줘", "자동설치 켜줘", "스킬 찾아줘" 등으로 말하면 해당 커맨드가 실행됩니다.

### 상세 옵션

```
/scout --quick            # 빠른 스캔 (점수 80+ 만)
/scout --category <cat>   # 특정 카테고리만 스캔

/compare <a> <b>          # 플러그인 비교표 생성
/cleanup --dry-run        # 정리 시뮬레이션
/explore [category]       # 마켓플레이스 카테고리 탐색
/audit --security         # 보안만 점검
/fork <src> <name>        # 플러그인 포크
```

## 점수 계산

**종합 점수 = (프로젝트 매칭 x 40%) + (인기도 x 30%) + (보안 x 30%)**

| 점수 | 등급 | 권장 |
|------|------|------|
| 90-100 | Excellent | 적극 추천 |
| 75-89 | Good | 추천 |
| 60-74 | Fair | 대안 검토 |
| 40-59 | Poor | 주의 |
| 0-39 | Not Recommended | 비추천 |

## 프로젝트 감지

자동으로 감지하는 프로젝트 타입:
- JavaScript/TypeScript (package.json, tsconfig.json)
- Python (requirements.txt, pyproject.toml)
- Rust (Cargo.toml)
- Go (go.mod)
- Java (pom.xml, build.gradle)
- PHP (composer.json)
- Ruby (Gemfile)

## 설정 (config.yaml)

```yaml
# 점수 가중치
scoring:
  project_match: 40
  popularity: 30
  security: 30

# 자동 추천
auto_recommend:
  enabled: true
  min_score: 60
  max_suggestions: 3

# 정리 기준
cleanup:
  unused_days: 30
  low_usage_count: 3

# 신뢰된 자동 설치 (v4.1)
auto_install:
  enabled: false               # /scout trusted-install on 으로 opt-in
  trusted_authors: ["Anthropic"]
  marketplace: "claude-plugins-official"
  lsp_language_filter: true
  check_conflicts: true
  detect_new_releases: true
  cache_catalog: true
  cache_ttl: 86400

# skills.sh 통합 (v4.1)
skills_sh:
  enabled: true
  auto_install_official: true  # Anthropic 스킬 자동 설치
  cache_ttl: 3600
  max_recommendations: 5
  combo_suggestions: true
```

## 파일 구조

```
.claude/plugins/
├── marketplace.json              # 마켓플레이스 정의
└── monol-plugin-scout/
    ├── plugin.json               # 플러그인 매니페스트
    ├── config.yaml               # 설정
    ├── CLAUDE.md                 # 이 파일
    ├── commands/
    │   ├── scout.md              # /scout 메인 커맨드
    │   ├── trusted-install.md    # /scout trusted-install (v4.1)
    │   ├── trust.md              # /scout trust (v4.1)
    │   ├── skills.md             # /scout skills (v4.1)
    │   ├── quiet.md              # /scout quiet
    │   ├── frequency.md          # /scout frequency
    │   ├── timing.md             # /scout timing
    │   ├── compare.md            # /scout compare
    │   ├── cleanup.md            # /scout cleanup
    │   ├── explore.md            # /scout explore
    │   ├── audit.md              # /scout audit
    │   └── fork.md               # /scout fork
    ├── skills/
    │   ├── plugin-evaluation.md  # 평가 방법론
    │   ├── trusted-install.md    # 자동 설치 스킬 (v4.1)
    │   ├── trust.md              # 신뢰 관리 스킬 (v4.1)
    │   └── skills.md             # 스킬 스카우트 스킬 (v4.1)
    ├── lib/
    │   ├── trusted-installer.sh  # 자동 설치 엔진 (v4.1)
    │   ├── trust-manager.sh      # 신뢰 작성자 관리 (v4.1)
    │   ├── skill-scout.sh        # skills.sh 연동 (v4.1)
    │   ├── recommendation-controller.sh
    │   ├── plugin-manager.sh
    │   ├── project-analyzer.sh
    │   ├── cache.sh
    │   ├── logger.sh
    │   ├── sync.sh
    │   └── ...
    ├── combos/                   # 워크플로우 조합
    ├── overrides/                # 플러그인 오버라이드
    └── data/
        ├── history.json          # 거절/설치 이력 + 신뢰/스킬 (v4.1)
        └── usage.json            # 사용량 추적
```

## 안전 규칙

1. **기본 자동 설치 금지** - 항상 사용자 동의 필요
2. **신뢰된 자동 설치** - opt-in 후 Anthropic 공식 플러그인만 (v4.1)
3. **Anthropic 스킬 자동 설치** - skills.sh의 공식 스킬은 기본 ON (v4.1)
4. **보안 경고 표시** - 위험한 플러그인에 경고
5. **설치 전 확인** - 명령어 확인 후 승인
6. **LSP 언어 필터** - 프로젝트와 무관한 LSP는 자동 설치 제외 (v4.1)
7. **충돌 감지** - 동일 기능 플러그인 중복 설치 방지 (v4.1)
8. **오프라인 대응** - 네트워크 실패 시 캐시 폴백 (v4.1)
9. **감사 로그** - `/scout trust export`로 전체 이력 내보내기 (v4.1)

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
