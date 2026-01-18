---
skill: plugin-evaluation
description: 플러그인 평가 방법론. 플러그인 점수 계산, 보안 검토, 호환성 분석 시 사용합니다.
proactive: false
triggers:
  - plugin_install
  - plugin_compare
---

# Plugin Evaluation Skill

플러그인을 체계적으로 평가하기 위한 방법론입니다.

## Composite Score Formula

```
Composite = (Project Match × 0.40) + (Popularity × 0.30) + (Security × 0.30)
```

**Rating Scale**:
| Score | Rating | Recommendation |
|-------|--------|----------------|
| 90-100 | Excellent | 적극 추천 |
| 75-89 | Good | 추천 |
| 60-74 | Fair | 대안 검토 필요 |
| 40-59 | Poor | 주의 필요 |
| 0-39 | Not Recommended | 비추천 |

---

## 1. Project Match Scoring (40%)

### Language Detection

| Config File | Language | Confidence |
|-------------|----------|------------|
| package.json | JavaScript/TypeScript | High |
| tsconfig.json | TypeScript | High |
| requirements.txt | Python | High |
| pyproject.toml | Python | High |
| Cargo.toml | Rust | High |
| go.mod | Go | High |
| pom.xml | Java | High |
| build.gradle | Java/Kotlin | High |
| composer.json | PHP | High |
| Gemfile | Ruby | High |

### Scoring Criteria

```yaml
language_match:
  exact: 30      # TypeScript plugin for TypeScript project
  related: 15    # TypeScript plugin for JavaScript project
  none: 0

framework_match:
  exact: 25      # React plugin for React project
  compatible: 15 # Frontend plugin for React project
  none: 0

category_relevance:
  high: 20       # Testing plugin for test-heavy project
  medium: 10
  low: 5

dependency_compatibility:
  no_conflicts: 15
  minor_conflicts: 5
  major_conflicts: 0

architecture_fit:
  excellent: 10
  good: 5
  poor: 0
```

---

## 2. Popularity Scoring (30%)

### GitHub Metrics

```yaml
stars:
  10000+: 30
  1000-9999: 25
  100-999: 15
  10-99: 10
  0-9: 5

recent_commits_90d:
  20+: 20
  5-19: 15
  1-4: 10
  0: 5

last_update:
  <30_days: 20
  30-90_days: 15
  90-180_days: 10
  180-365_days: 5
  >365_days: 0

issue_health:
  excellent: 15  # >80% closed, fast response
  good: 10
  moderate: 5
  poor: 0

fork_activity:
  active: 15
  moderate: 10
  low: 5
```

### Normalization Formula

For highly variable metrics:
```
normalized_stars = min(log10(stars + 1) / log10(100000) × 100, 100)
```

---

## 3. Security Scoring (30%)

### License Analysis

```yaml
permissive:  # 30 points
  - MIT
  - Apache-2.0
  - BSD-2-Clause
  - BSD-3-Clause
  - ISC

copyleft:    # 20 points
  - GPL-3.0
  - GPL-2.0
  - LGPL-3.0
  - MPL-2.0

restrictive: # 0-10 points
  - proprietary: 10
  - unknown: 0
  - custom: 5
```

### Vulnerability Assessment

```yaml
vulnerability_scoring:
  none_known: 40
  minor_fixed: 35     # had issues, all patched
  minor_open: 20      # low-severity unpatched
  moderate_open: 10
  critical_open: 0
  no_data: 20         # cannot assess
```

### Author Reputation

```yaml
author_scoring:
  official_anthropic: 30
  verified_org:
    major_company: 25   # Microsoft, Google, etc.
    known_org: 20
  individual:
    established: 15     # many popular repos
    known: 10
    new: 5
  unknown: 0
```

---

## Evaluation Output Template

```yaml
plugin_evaluation:
  name: [plugin-name]
  marketplace: [marketplace-id]
  version: [version]

  scores:
    project_match: [0-100]
    popularity: [0-100]
    security: [0-100]
    composite: [0-100]
    rating: [Excellent/Good/Fair/Poor/Not Recommended]

  project_analysis:
    language_match: [language] ([status])
    framework_match: [framework] ([status])
    category_relevance: [high/medium/low]

  activity_analysis:
    github_stars: [count]
    recent_commits: [count]
    last_update: [date]

  security_analysis:
    license: [type]
    license_compatible: [true/false]
    known_vulnerabilities: [none/minor/critical]
    author: [name] ([type])

  warnings:
    - level: [critical/moderate/informational]
      message: [warning text]

  recommendation:
    install: [true/false]
    confidence: [high/medium/low]
    command: "/plugin install [name]@[marketplace]"
```

---

## Reference Files

For detailed information, see:

- `docs/references/scoring-methodology.md` - 상세 점수 계산 공식
- `docs/references/security-checklist.md` - 설치 전 보안 체크리스트
- `docs/references/license-compatibility.md` - 라이선스 호환성 매트릭스
