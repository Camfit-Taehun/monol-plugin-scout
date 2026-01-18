---
plugin: code-review
version: ">=1.0.0"
---

# code-review 커스텀 규칙

## 추가 체크 항목
- 한국어 주석 권장
- console.log 사용 금지 (production 코드)
- any 타입 사용 시 경고
- 함수 길이 50줄 초과 시 분리 제안

## 무시 항목
- 테스트 파일 (*.test.ts, *.spec.ts)
- 설정 파일 (*.config.js)
- 마이그레이션 파일

## 추가 메시지
- 리뷰 시작 시: "캠핏 코드 컨벤션에 따라 리뷰합니다."
- 리뷰 완료 시: "리뷰 완료! 수고하셨습니다. 🎉"
