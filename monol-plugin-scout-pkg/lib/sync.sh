#!/bin/bash
# monol-server 동기화 모듈 (scout)
# 플러그인 이벤트를 서버로 전송

# 설정 로드
load_sync_config() {
  local config_file="${PLUGIN_ROOT:-$(dirname "$0")/..}/config.yaml"

  if [ -f "$config_file" ]; then
    SYNC_ENABLED=$(grep "^sync_enabled:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    SYNC_SERVER_URL=$(grep "^sync_server_url:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    SYNC_TEAM=$(grep "^sync_team:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    SYNC_TIMEOUT=$(grep "^sync_timeout:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
  fi

  # 환경변수 우선
  SYNC_ENABLED="${MONOL_SYNC_ENABLED:-${SYNC_ENABLED:-true}}"
  SYNC_SERVER_URL="${MONOL_SERVER_URL:-${SYNC_SERVER_URL:-http://localhost:3030}}"
  SYNC_TEAM="${MONOL_TEAM:-${SYNC_TEAM:-}}"
  SYNC_TIMEOUT="${SYNC_TIMEOUT:-5}"

  # 사용자 감지
  SYNC_USER="${MONOL_USER:-$(git config user.name 2>/dev/null || echo "$USER")}"
}

# 서버 연결 확인
check_server() {
  local health_url="${SYNC_SERVER_URL}/api/health"

  if curl -s --max-time 2 "$health_url" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# 이벤트 전송
send_event() {
  local event_type="$1"
  local event_data="$2"

  # 동기화 비활성화 확인
  if [ "$SYNC_ENABLED" != "true" ]; then
    return 0
  fi

  # 서버 URL 확인
  if [ -z "$SYNC_SERVER_URL" ]; then
    return 0
  fi

  # JSON 페이로드 생성
  local payload=$(cat <<EOF
{
  "user": "$SYNC_USER",
  "team": "$SYNC_TEAM",
  "plugin": "monol-scout",
  "type": "$event_type",
  "data": $event_data
}
EOF
)

  # 전송 (실패해도 무시)
  local response
  response=$(curl -s --max-time "$SYNC_TIMEOUT" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${SYNC_SERVER_URL}/api/events" 2>/dev/null)

  if echo "$response" | grep -q '"success":true' 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# 플러그인 검색 이벤트
sync_plugin_searched() {
  local query="$1"
  local category="$2"
  local results_count="$3"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "query": "$query",
  "category": "$category",
  "resultsCount": ${results_count:-0}
}
EOF
)

  send_event "plugin_searched" "$event_data"
}

# 플러그인 설치 이벤트
sync_plugin_installed() {
  local plugin_name="$1"
  local plugin_version="$2"
  local source="$3"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "pluginName": "$plugin_name",
  "version": "$plugin_version",
  "source": "$source"
}
EOF
)

  send_event "plugin_installed" "$event_data"
}

# 플러그인 제거 이벤트
sync_plugin_removed() {
  local plugin_name="$1"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "pluginName": "$plugin_name"
}
EOF
)

  send_event "plugin_removed" "$event_data"
}

# 스킬 사용 이벤트
sync_skill_used() {
  local skill_name="$1"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "skillName": "$skill_name"
}
EOF
)

  send_event "skill_used" "$event_data"
}

# 감사 실행 이벤트
sync_audit_run() {
  local plugins_count="$1"
  local issues_found="$2"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "pluginsCount": ${plugins_count:-0},
  "issuesFound": ${issues_found:-0}
}
EOF
)

  send_event "audit_run" "$event_data"
}

# 신뢰된 자동 설치 이벤트
sync_trusted_install() {
  local installed_count="$1"
  local skipped_count="$2"
  local new_releases="$3"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "installedCount": ${installed_count:-0},
  "skippedCount": ${skipped_count:-0},
  "newReleases": ${new_releases:-0}
}
EOF
)

  send_event "trusted_install" "$event_data"
}

# 스킬 설치 이벤트
sync_skill_installed() {
  local skill_id="$1"
  local source="$2"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "skillId": "$skill_id",
  "source": "$source"
}
EOF
)

  send_event "skill_installed" "$event_data"
}

# 정리 실행 이벤트
sync_cleanup_run() {
  local removed_count="$1"

  load_sync_config

  local event_data=$(cat <<EOF
{
  "removedCount": ${removed_count:-0}
}
EOF
)

  send_event "cleanup_run" "$event_data"
}
