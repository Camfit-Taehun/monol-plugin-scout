---
description: 설치된 플러그인 보안 및 업데이트 점검
use_when:
  - 사용자가 플러그인 보안을 점검하고 싶을 때
  - 업데이트 가능한 플러그인을 확인하고 싶을 때
---

# /scout audit - 보안 및 업데이트 점검

설치된 플러그인의 보안 및 업데이트 상태를 점검합니다.

## 사용법

```
/scout audit              # 전체 점검
/scout audit --security   # 보안만 점검
/scout audit --updates    # 업데이트만 점검
```

## 인자: $ARGUMENTS

## 동작

### 1. 설치된 플러그인 조회

`~/.claude/settings.json`과 `.claude/settings.json`에서 `enabledPlugins` 확인.

### 2. 보안 점검 항목

| 항목 | 상태 | 설명 |
|------|------|------|
| 라이선스 | ✓ / ⚠ / ✗ | MIT/Apache (✓), GPL (⚠), Unknown (✗) |
| 취약점 | ✓ / ✗ | npm audit, GitHub Security Advisories |
| 저자 검증 | ✓ / ⚠ | Official (✓), Verified (⚠), Unverified (✗) |
| 업데이트 | ✓ / ⚠ | <1년 (✓), 1년+ (⚠) |

### 3. 점검 결과 출력

```
🔒 플러그인 보안 점검

설치된 플러그인: 7개

## 보안 상태

| 플러그인 | 라이선스 | 취약점 | 저자 | 업데이트 |
|----------|----------|--------|------|----------|
| typescript-lsp | ✓ MIT | ✓ | ✓ Official | ✓ 2일 전 |
| code-review | ✓ Apache | ✓ | ✓ Official | ✓ 7일 전 |
| old-plugin | ⚠ GPL | ✓ | ⚠ Unverified | ✗ 14개월 전 |

## 경고 (1개)

⚠ old-plugin
  - 14개월간 업데이트 없음
  - 검증되지 않은 저자
  - GPL 라이선스 (제한적 호환성)

권장: /plugin uninstall old-plugin

## 업데이트 가능 (2개)

| 플러그인 | 현재 | 최신 |
|----------|------|------|
| typescript-lsp | 1.2.0 | 1.3.0 |
| code-review | 2.0.0 | 2.1.0 |

업데이트: /plugin update <name>
```

### 4. 심각한 경고

보안 문제가 심각한 경우:

```
🚨 보안 경고

다음 플러그인에 알려진 취약점이 있습니다:

• vulnerable-plugin (CVE-2025-1234)
  심각도: High
  영향: 원격 코드 실행 가능

즉시 제거를 권장합니다:
/plugin uninstall vulnerable-plugin
```

## 예시

```
/scout audit
→ 전체 보안 및 업데이트 점검

/scout audit --security
→ 보안만 점검

/scout audit --updates
→ 업데이트 가능 여부만 확인
```
