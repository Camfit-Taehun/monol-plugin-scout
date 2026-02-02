# Plugin Scout v2.1

Claude Code 플러그인 마켓플레이스 모니터링 및 추천 에이전트

## v2.1 새 기능

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
| `/scout quiet` | 무음, 조용히 | 무음 모드 설정 (v2.1) |
| `/scout frequency` | 빈도, 횟수 | 추천 빈도 설정 (v2.1) |
| `/scout timing` | 타이밍, 추천시점 | 스마트 타이밍 (v2.1) |
| `/compare` | 비교, 플러그인비교 | 플러그인 비교 |
| `/cleanup` | 정리, 플러그인정리 | 미사용 정리 |
| `/explore` | 탐색, 마켓플레이스 | 카테고리 탐색 |
| `/audit` | 점검, 보안점검 | 보안/업데이트 점검 |
| `/fork` | 포크, 복사 | 플러그인 포크 |

**한글 자연어 입력 지원**: "플러그인 추천해줘", "보안 점검해줘" 등으로 말하면 해당 커맨드가 실행됩니다.

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

**종합 점수 = (프로젝트 매칭 × 40%) + (인기도 × 30%) + (보안 × 30%)**

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
    │   ├── quiet.md              # /scout quiet (v2.1)
    │   ├── frequency.md          # /scout frequency (v2.1)
    │   ├── timing.md             # /scout timing (v2.1)
    │   ├── compare.md            # /scout compare
    │   ├── cleanup.md            # /scout cleanup
    │   ├── explore.md            # /scout explore
    │   ├── audit.md              # /scout audit
    │   └── fork.md               # /scout fork
    ├── skills/
    │   └── plugin-evaluation.md  # 평가 방법론
    ├── lib/
    │   └── recommendation-controller.sh  # 추천 제어 (v2.1)
    ├── combos/                   # 워크플로우 조합
    ├── overrides/                # 플러그인 오버라이드
    └── data/
        ├── history.json          # 거절/설치 이력
        └── usage.json            # 사용량 추적
```

## 안전 규칙

1. **자동 설치 금지** - 항상 사용자 동의 필요
2. **보안 경고 표시** - 위험한 플러그인에 경고
3. **설치 전 확인** - 명령어 확인 후 승인

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
