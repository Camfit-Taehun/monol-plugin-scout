# Plugin Scout v2.0

Claude Code 플러그인 마켓플레이스 모니터링 및 추천 에이전트

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
- `/scout`, `/scout compare`, `/scout cleanup` 등 스킬 사용 가능
- 프로젝트 분석 후 맞춤 플러그인 추천

## 스킬 (Commands)

```
/scout                    # 프로젝트 분석 후 플러그인 추천
/scout --quick            # 빠른 스캔 (점수 80+ 만)
/scout --category <cat>   # 특정 카테고리만 스캔

/scout compare <a> <b>    # 플러그인 비교표 생성
/scout cleanup            # 미사용 플러그인 정리 제안
/scout explore [category] # 마켓플레이스 카테고리 탐색
/scout audit              # 보안 및 업데이트 점검
/scout fork <src> <name>  # 플러그인 포크
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
    │   ├── compare.md            # /scout compare
    │   ├── cleanup.md            # /scout cleanup
    │   ├── explore.md            # /scout explore
    │   ├── audit.md              # /scout audit
    │   └── fork.md               # /scout fork
    ├── skills/
    │   └── plugin-evaluation.md  # 평가 방법론
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
