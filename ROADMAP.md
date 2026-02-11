# Plugin Scout 로드맵

## 현재 버전: v4.1.0

---

## 진행률 요약

```
Discovery       ████████████████████ 100%
Recommendation  ████████████████████ 100%
UX              ████████████████████ 100%
Learning        ████████████████████ 100%
Trusted Install ████████████████████ 100%
Skill Scout     ████████████████████ 100%
```

**총 완성도: 100%**

---

## 완료된 버전

### v2.0.0 - 기본 기능
- [x] 6개 스킬: scout, compare, cleanup, explore, audit, fork
- [x] 한글 자연어 입력 지원
- [x] 점수 기반 추천 시스템
- [x] 마켓플레이스 탐색

### v2.1.0 - Hooks 시스템
- [x] Stop Hook: 세션 종료 시 자동 추천
- [x] SessionStart Hook: 세션 시작 기록
- [x] SessionEnd Hook: 사용량 집계

### v2.2.0 - 사용량 추적
- [x] usage.json: 플러그인별 사용 횟수
- [x] analytics.json: 세션별 분석 데이터
- [x] track-usage.sh: 자동 기록 스크립트

### v2.3.0 - CLI 콘솔
- [x] `/scout console` 명령어
- [x] ASCII 대시보드 뷰
- [x] 플러그인/사용자/분석 뷰

### v2.4.0 ~ v2.5.0 - 웹 콘솔 & 학습 시스템
- [x] 웹 콘솔 UI 프로토타입 (`web/console.html`)
- [x] Mock API 구조 설계 (`api/mock/`)
- [x] 플러그인/서버 역할 분리 문서 (`docs/ARCHITECTURE.md`)
- [x] 학습 시스템 완성 (아래 상세)

---

## 학습 시스템 (v2.5.0 완료)

### 거절 학습 (rejection-learner.sh)
- [x] 거절 이유 추적 및 저장
- [x] 동일 플러그인 재추천 방지 (쿨다운)
- [x] 카테고리별 거절 패턴 학습
- [x] 3회 이상 거절 시 영구 차단

### 프로필 학습 (profile-learner.sh)
- [x] 사용자 선호도 저장 (카테고리, 프로젝트 타입)
- [x] 시간대별 활동 패턴 분석
- [x] 추천 수락률 추적
- [x] 프로필 기반 점수 조정

### 트렌드 학습 (trend-learner.sh)
- [x] 주간/월간 인기 플러그인 추적
- [x] 카테고리별 트렌드 변화 감지
- [x] 새 플러그인 출현 알림
- [x] 트렌딩 플러그인 계산

### AI 기반 추천 (ai-recommender.sh)
- [x] 코드 구조 분석 (package.json, requirements.txt 등)
- [x] 의존성 그래프 구축
- [x] 프로젝트 시그니처 매칭
- [x] 유사 프로젝트 참고 추천

### 협업 학습 (team-learner.sh)
- [x] 팀원 선택 패턴 통합
- [x] 팀 필수/금지 플러그인 정책
- [x] 온보딩 추천
- [x] 팀 사용 리포트

---

## Phase 3~5: 핵심 기능 (완료)

### 3.1 추천 품질 개선 ✅
- [x] 프로젝트 분석 정확도 향상 (ai-recommender.sh)
- [x] 의존성 기반 추천 (package.json, requirements.txt 등 분석)
- [x] 최근 작업 컨텍스트 반영 (profile-learner.sh)

### 3.2 거절 학습 ✅
- [x] 거절 이유 추적 및 저장
- [x] 동일 플러그인 재추천 방지
- [x] 카테고리별 거절 패턴 학습

### 4.1 추천 빈도 조절 ✅
- [x] `/scout quiet on/off` - 무음 모드
- [x] 세션당 N회 제한 옵션
- [x] 하루 N회 제한 설정

### 4.2 스마트 타이밍 ✅
- [x] 커밋 직후에만 추천
- [x] PR 생성 후에만 추천
- [x] 쿨다운 설정 (config.yaml)

### 5.1~5.3 팀 협업 ✅
- [x] `.claude/team-plugins.json` 정의
- [x] 팀 필수/금지 플러그인 목록
- [x] 새 팀원 감지 및 온보딩 추천
- [x] 팀원별 플러그인 사용 현황

---

## v4.1.0 - Trusted Auto-Install + Skill Scout (완료)

### Trusted Auto-Install ✅
- [x] `lib/trusted-installer.sh` — 공식 플러그인 자동 설치 엔진
- [x] LSP 언어 필터링 (11개 언어 매핑)
- [x] 동일 기능 플러그인 충돌 감지
- [x] 신규 출시 감지 (이전 캐시 vs 현재 비교)
- [x] 오프라인 캐시 폴백
- [x] opt-in 이중 확인 (config.yaml + history.json)
- [x] `/scout trusted-install [on|off|status|check|run]` 커맨드
- [x] SessionStart 훅 백그라운드 실행

### Trust Manager ✅
- [x] `lib/trust-manager.sh` — 신뢰 작성자 CRUD
- [x] 감사 로그 내보내기 (`/scout trust export`)
- [x] `/scout trust [@author|remove|list|export]` 커맨드

### Skill Scout (skills.sh) ✅
- [x] `lib/skill-scout.sh` — skills.sh API 연동
- [x] 페이지네이션 카탈로그 동기화 (500/page)
- [x] Anthropic 공식 스킬 자동 설치 (`topSource: anthropics/skills`)
- [x] 스코어링 추천 (인기도 50% + 프로젝트 매칭 30% + 신뢰도 20%)
- [x] 시너지 콤보 추천 (설치된 플러그인 기반)
- [x] `/scout skills [search|recommend|install|list|combos]` 커맨드
- [x] SessionStart 훅 백그라운드 자동 설치

---

## Phase 6~7: 확장 (장기)

### 6.1 성능
- [ ] 마켓플레이스 캐싱 (24시간)
- [ ] 증분 업데이트
- [ ] 백그라운드 스캔

### 6.2 안정성
- [ ] 플러그인 에러 추적
- [ ] 자동 복구 메커니즘
- [ ] 롤백 지원

### 7.1 웹 콘솔 정식 버전
- [ ] 실제 API 서버 구현
- [ ] 실시간 데이터 연동
- [ ] 인증/권한 관리

### 7.2 플러그인 생성 도우미
- [ ] `/scout create` 명령어
- [ ] 템플릿 기반 생성
- [ ] 마켓플레이스 등록 가이드

---

## 버전 계획

| 버전 | 내용 | 상태 |
|-----|------|------|
| v2.0 | 기본 기능 (6개 스킬) | ✅ 완료 |
| v2.1 | Hooks 시스템 | ✅ 완료 |
| v2.2 | 사용량 추적 | ✅ 완료 |
| v2.3 | CLI 콘솔 | ✅ 완료 |
| v2.5 | 웹 콘솔 & 학습 시스템 | ✅ 완료 |
| v4.1 | Trusted Auto-Install + Skill Scout | ✅ 완료 |
| v4.2 | 팀 필수 플러그인 + 마이그레이션 | 예정 |
| v5.0 | 엔터프라이즈 확장 | 장기 |

---

## 아이디어 백로그

추후 검토할 아이디어:

- [ ] Slack 연동 알림
- [ ] VS Code 확장
- [ ] 의존성 그래프 시각화
- [ ] A/B 테스트 지원
- [ ] 플러그인 번들 (여러 개 묶어서 설치)
- [ ] GitHub Actions 연동
- [ ] 실제 API 서버 연동 (웹 콘솔 정식 버전)
