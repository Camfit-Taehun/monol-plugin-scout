#!/bin/bash
# Plugin Scout - skills.sh 통합 모듈
# skills.sh 마켓플레이스에서 스킬 탐색, 추천, 설치

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
DATA_DIR="$PLUGIN_ROOT/data"

SKILLS_API="https://skills.sh/api"
CACHE_DIR="$DATA_DIR/.cache"
SKILLS_CACHE="$CACHE_DIR/skills-catalog.json"
SKILLS_DIR="$HOME/.claude/skills"
HISTORY_FILE="$DATA_DIR/history.json"
CONFIG_FILE="$PLUGIN_ROOT/config.yaml"
INSTALL_LOG="$DATA_DIR/.last-skill-install.json"

CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# ============================================================================
# Config reader
# ============================================================================

# config.yaml의 skills_sh 섹션에서 값 읽기
# Usage: read_config <key> <default>
read_config() {
  local key="$1"
  local default="$2"

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "$default"
    return
  fi

  # skills_sh 섹션에서 key 추출 (grep + awk)
  local value
  value=$(grep -A 20 "^skills_sh:" "$CONFIG_FILE" | grep "^  ${key}:" | awk '{print $2}' | tr -d '"' | tr -d "'")

  if [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# ============================================================================
# npx 확인
# ============================================================================

check_npx() {
  if command -v npx &> /dev/null; then
    echo "npx available: $(npx --version 2>/dev/null)"
    return 0
  else
    echo "Error: npx not found."
    echo ""
    echo "npx is required for skills.sh integration."
    echo "Install Node.js (v18+) to get npx:"
    echo "  - macOS:   brew install node"
    echo "  - Linux:   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs"
    echo "  - Windows: https://nodejs.org/"
    echo "  - nvm:     nvm install --lts"
    return 1
  fi
}

# ============================================================================
# 카탈로그 가져오기
# ============================================================================

fetch_catalog() {
  mkdir -p "$CACHE_DIR"

  # 캐시 TTL 확인
  local cache_ttl
  cache_ttl=$(read_config "cache_ttl" "3600")

  if [ -f "$SKILLS_CACHE" ]; then
    local cache_age=0
    if [[ "$OSTYPE" == "darwin"* ]]; then
      local cache_mtime
      cache_mtime=$(stat -f "%m" "$SKILLS_CACHE" 2>/dev/null || echo 0)
      local now
      now=$(date +%s)
      cache_age=$((now - cache_mtime))
    else
      local cache_mtime
      cache_mtime=$(stat -c "%Y" "$SKILLS_CACHE" 2>/dev/null || echo 0)
      local now
      now=$(date +%s)
      cache_age=$((now - cache_mtime))
    fi

    if [ "$cache_age" -lt "$cache_ttl" ]; then
      cat "$SKILLS_CACHE"
      return 0
    fi
  fi

  # API에서 가져오기 (페이지네이션)
  local api_base
  api_base=$(read_config "api_base" "$SKILLS_API")

  local all_skills="[]"
  local offset=0
  local limit=500
  local has_more=true

  while [ "$has_more" = "true" ]; do
    local response
    response=$(curl -s --max-time 10 "${api_base}/skills?limit=${limit}&offset=${offset}" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
      # 네트워크 실패 시 캐시 폴백
      if [ -f "$SKILLS_CACHE" ]; then
        cat "$SKILLS_CACHE"
        return 0
      fi
      echo "[]"
      return 1
    fi

    # 응답에서 스킬 추출하여 병합
    local skills_page
    skills_page=$(echo "$response" | jq -c '.skills // .data // []' 2>/dev/null)

    if [ -z "$skills_page" ] || [ "$skills_page" = "null" ] || [ "$skills_page" = "[]" ]; then
      break
    fi

    all_skills=$(echo "$all_skills" "$skills_page" | jq -s '.[0] + .[1]' 2>/dev/null)

    # hasMore 확인
    has_more=$(echo "$response" | jq -r '.hasMore // false' 2>/dev/null)
    offset=$((offset + limit))

    # Rate limit
    sleep 0.1
  done

  # 캐시 저장
  echo "$all_skills" > "$SKILLS_CACHE"
  echo "$all_skills"
}

# ============================================================================
# Anthropic 공식 스킬 체크
# ============================================================================

is_anthropic_skill() {
  local skill_json="$1"
  local top_source
  top_source=$(echo "$skill_json" | jq -r '.topSource // ""' 2>/dev/null)

  if [ "$top_source" = "anthropics/skills" ]; then
    return 0
  else
    return 1
  fi
}

# ============================================================================
# 설치된 스킬 목록
# ============================================================================

get_installed_skills() {
  local installed=()

  # 글로벌 스킬 (~/.claude/skills/)
  if [ -d "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
      if [ -d "$skill_dir" ]; then
        local name
        name=$(basename "$skill_dir")
        installed+=("$name")
      fi
    done
  fi

  # 플러그인 내부 스킬
  if [ -d "$PLUGIN_ROOT/skills" ]; then
    for skill_file in "$PLUGIN_ROOT/skills"/*.md; do
      if [ -f "$skill_file" ]; then
        local name
        name=$(basename "$skill_file" .md)
        installed+=("$name")
      fi
    done
  fi

  printf '%s\n' "${installed[@]}" | jq -R -s -c 'split("\n") | map(select(. != "")) | unique'
}

# ============================================================================
# Anthropic 공식 스킬 자동 설치
# ============================================================================

auto_install_official() {
  local auto_enabled
  auto_enabled=$(read_config "auto_install_official" "true")

  if [ "$auto_enabled" != "true" ]; then
    echo '{"skipped": true, "reason": "auto_install_official disabled"}'
    return 0
  fi

  # npx 확인
  if ! check_npx > /dev/null 2>&1; then
    echo '{"skipped": true, "reason": "npx not available"}'
    return 1
  fi

  local catalog
  catalog=$(fetch_catalog)

  if [ "$catalog" = "[]" ] || [ -z "$catalog" ]; then
    echo '{"skipped": true, "reason": "empty catalog"}'
    return 0
  fi

  local installed
  installed=$(get_installed_skills)

  local results=()
  local install_count=0
  local skip_count=0
  local fail_count=0

  # Anthropic 공식 스킬 필터링 및 설치
  local anthropic_skills
  anthropic_skills=$(echo "$catalog" | jq -c '[.[] | select(.topSource == "anthropics/skills")]' 2>/dev/null)

  local skill_count
  skill_count=$(echo "$anthropic_skills" | jq 'length' 2>/dev/null)

  for i in $(seq 0 $((skill_count - 1))); do
    local skill
    skill=$(echo "$anthropic_skills" | jq -c ".[$i]" 2>/dev/null)

    local skill_id
    skill_id=$(echo "$skill" | jq -r '.id // .name // ""' 2>/dev/null)

    if [ -z "$skill_id" ]; then
      continue
    fi

    # 이미 설치되었는지 확인
    local is_installed
    is_installed=$(echo "$installed" | jq -r --arg id "$skill_id" 'map(select(. == $id)) | length' 2>/dev/null)

    if [ "$is_installed" -gt 0 ] 2>/dev/null; then
      skip_count=$((skip_count + 1))
      continue
    fi

    # 설치 시도
    local install_result
    install_result=$(npx skills add "$skill_id" 2>&1)

    if [ $? -eq 0 ]; then
      install_count=$((install_count + 1))
      results+=("{\"id\": \"$skill_id\", \"status\": \"installed\"}")

      # history.json에 기록
      if [ -f "$HISTORY_FILE" ]; then
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq --arg skill "$skill_id" --arg ts "$timestamp" '
          .lastUpdated = $ts |
          .skills.installed[$skill] = {
            installedAt: $ts,
            source: "anthropics/skills",
            autoInstalled: true
          }
        ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
      fi
    else
      fail_count=$((fail_count + 1))
      results+=("{\"id\": \"$skill_id\", \"status\": \"failed\", \"error\": \"$(echo "$install_result" | head -1)\"}")
    fi
  done

  # 결과 기록
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local results_json
  results_json=$(printf '%s\n' "${results[@]}" | jq -s -c '.' 2>/dev/null || echo "[]")

  cat > "$INSTALL_LOG" <<EOF
{
  "timestamp": "$timestamp",
  "type": "auto_install_official",
  "installed": $install_count,
  "skipped": $skip_count,
  "failed": $fail_count,
  "details": $results_json
}
EOF

  cat "$INSTALL_LOG"
}

# ============================================================================
# 스킬 점수 계산
# ============================================================================

score_skill() {
  local skill_json="$1"
  local project_types="$2"

  local score=0

  # --- installs popularity: 50% ---
  local installs
  installs=$(echo "$skill_json" | jq -r '.installs // .downloads // 0' 2>/dev/null)

  # 정규화: 상위 기준 1000 설치를 100점으로 가정
  local pop_score=0
  if [ "$installs" -ge 1000 ] 2>/dev/null; then
    pop_score=100
  elif [ "$installs" -ge 500 ] 2>/dev/null; then
    pop_score=80
  elif [ "$installs" -ge 100 ] 2>/dev/null; then
    pop_score=60
  elif [ "$installs" -ge 50 ] 2>/dev/null; then
    pop_score=40
  elif [ "$installs" -ge 10 ] 2>/dev/null; then
    pop_score=20
  else
    pop_score=10
  fi

  # --- project matching: 30% ---
  local match_score=0
  local skill_name
  skill_name=$(echo "$skill_json" | jq -r '.name // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  local skill_tags
  skill_tags=$(echo "$skill_json" | jq -r '(.tags // []) | join(" ")' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  local skill_desc
  skill_desc=$(echo "$skill_json" | jq -r '.description // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

  local search_text="$skill_name $skill_tags $skill_desc"

  # project_types가 JSON 배열인 경우 파싱
  if echo "$project_types" | jq -e '.' > /dev/null 2>&1; then
    local type_count
    type_count=$(echo "$project_types" | jq -r '.[]' 2>/dev/null | while read -r ptype; do
      if echo "$search_text" | grep -qi "$ptype"; then
        echo "match"
      fi
    done | wc -l | tr -d ' ')

    if [ "$type_count" -gt 0 ] 2>/dev/null; then
      match_score=$((type_count * 33))
      [ "$match_score" -gt 100 ] && match_score=100
    fi
  fi

  # --- source trust: 20% ---
  local trust_score=0
  local top_source
  top_source=$(echo "$skill_json" | jq -r '.topSource // ""' 2>/dev/null)

  case "$top_source" in
    anthropics/*) trust_score=100 ;;
    verified/*|official/*) trust_score=70 ;;
    *) trust_score=40 ;;
  esac

  # 가중 합산
  score=$(( (pop_score * 50 + match_score * 30 + trust_score * 20) / 100 ))

  # 0-100 범위 제한
  [ "$score" -gt 100 ] && score=100
  [ "$score" -lt 0 ] && score=0

  echo "$score"
}

# ============================================================================
# 추천
# ============================================================================

recommend() {
  local count="${1:-5}"
  local max_count
  max_count=$(read_config "max_recommendations" "5")

  if [ "$count" -gt "$max_count" ] 2>/dev/null; then
    count="$max_count"
  fi

  local catalog
  catalog=$(fetch_catalog)

  if [ "$catalog" = "[]" ] || [ -z "$catalog" ]; then
    echo "[]"
    return 0
  fi

  local installed
  installed=$(get_installed_skills)

  # 프로젝트 타입 가져오기
  local project_types="[]"
  if [ -f "$PLUGIN_ROOT/lib/project-analyzer.sh" ]; then
    project_types=$(bash "$PLUGIN_ROOT/lib/project-analyzer.sh" types 2>/dev/null || echo "[]")
  fi

  # 각 스킬 점수 계산 (설치된 것 제외)
  local skill_count
  skill_count=$(echo "$catalog" | jq 'length' 2>/dev/null)

  local scored_skills="[]"

  for i in $(seq 0 $((skill_count - 1))); do
    local skill
    skill=$(echo "$catalog" | jq -c ".[$i]" 2>/dev/null)

    local skill_id
    skill_id=$(echo "$skill" | jq -r '.id // .name // ""' 2>/dev/null)

    if [ -z "$skill_id" ]; then
      continue
    fi

    # 이미 설치된 스킬 제외
    local is_installed
    is_installed=$(echo "$installed" | jq -r --arg id "$skill_id" 'map(select(. == $id)) | length' 2>/dev/null)

    if [ "$is_installed" -gt 0 ] 2>/dev/null; then
      continue
    fi

    local skill_score
    skill_score=$(score_skill "$skill" "$project_types")

    scored_skills=$(echo "$scored_skills" | jq --argjson skill "$skill" --argjson score "$skill_score" '. + [$skill + {"_score": $score}]' 2>/dev/null)
  done

  # 점수 내림차순 정렬, 상위 N개
  echo "$scored_skills" | jq -c --argjson n "$count" '[sort_by(-._score)][:$n]' 2>/dev/null || echo "[]"
}

# ============================================================================
# 키워드 검색
# ============================================================================

search() {
  local query="$1"

  if [ -z "$query" ]; then
    echo "Error: search query required"
    echo "Usage: $0 search <query>"
    return 1
  fi

  local catalog
  catalog=$(fetch_catalog)

  if [ "$catalog" = "[]" ] || [ -z "$catalog" ]; then
    echo "[]"
    return 0
  fi

  local query_lower
  query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

  # 프로젝트 타입
  local project_types="[]"
  if [ -f "$PLUGIN_ROOT/lib/project-analyzer.sh" ]; then
    project_types=$(bash "$PLUGIN_ROOT/lib/project-analyzer.sh" types 2>/dev/null || echo "[]")
  fi

  # 이름, 태그, 설명에서 검색 (대소문자 무시)
  local matches
  matches=$(echo "$catalog" | jq -c --arg q "$query_lower" '[.[] | select(
    (.name // "" | ascii_downcase | contains($q)) or
    ((.tags // []) | map(ascii_downcase) | any(contains($q))) or
    (.description // "" | ascii_downcase | contains($q))
  )]' 2>/dev/null)

  if [ "$matches" = "[]" ] || [ -z "$matches" ]; then
    echo "[]"
    return 0
  fi

  # 매치된 스킬에 점수 추가
  local match_count
  match_count=$(echo "$matches" | jq 'length' 2>/dev/null)

  local scored_matches="[]"

  for i in $(seq 0 $((match_count - 1))); do
    local skill
    skill=$(echo "$matches" | jq -c ".[$i]" 2>/dev/null)

    local skill_score
    skill_score=$(score_skill "$skill" "$project_types")

    scored_matches=$(echo "$scored_matches" | jq --argjson skill "$skill" --argjson score "$skill_score" '. + [$skill + {"_score": $score}]' 2>/dev/null)
  done

  # 점수순 정렬
  echo "$scored_matches" | jq -c '[sort_by(-._score)]' 2>/dev/null || echo "[]"
}

# ============================================================================
# 시너지 콤보 추천
# ============================================================================

suggest_combos() {
  local combo_enabled
  combo_enabled=$(read_config "combo_suggestions" "true")

  if [ "$combo_enabled" != "true" ]; then
    echo '{"skipped": true, "reason": "combo_suggestions disabled"}'
    return 0
  fi

  # 설치된 플러그인 조회
  local installed_plugins="[]"
  if [ -f "$CLAUDE_SETTINGS" ] && command -v jq &> /dev/null; then
    installed_plugins=$(jq -r '[.enabledPlugins // {} | to_entries[] | select(.value == true) | .key]' "$CLAUDE_SETTINGS" 2>/dev/null || echo "[]")
  fi

  local catalog
  catalog=$(fetch_catalog)

  # 콤보 매핑: 플러그인 키워드 → 보완 스킬 키워드
  local combos='{
    "typescript-lsp": ["typescript-strict", "type-coverage", "ts-refactor"],
    "code-review": ["pr-description", "review-checklist"],
    "commit-commands": ["conventional-commits", "changelog-gen"],
    "sentry": ["error-tracking", "alert-config"],
    "react": ["react-patterns", "component-gen"],
    "testing": ["test-gen", "coverage-report"]
  }'

  local recommendations="[]"

  # 각 설치된 플러그인에 대해 콤보 검색
  echo "$installed_plugins" | jq -r '.[]' 2>/dev/null | while read -r plugin; do
    local plugin_lower
    plugin_lower=$(echo "$plugin" | tr '[:upper:]' '[:lower:]')

    # 콤보 맵에서 매칭 키워드 찾기
    echo "$combos" | jq -r 'to_entries[] | .key' 2>/dev/null | while read -r combo_key; do
      if echo "$plugin_lower" | grep -qi "$combo_key"; then
        local skill_keywords
        skill_keywords=$(echo "$combos" | jq -r --arg k "$combo_key" '.[$k][]' 2>/dev/null)

        echo "$skill_keywords" | while read -r keyword; do
          # 카탈로그에서 매칭 스킬 검색
          local matched
          matched=$(echo "$catalog" | jq -c --arg kw "$keyword" '[.[] | select(
            (.name // "" | ascii_downcase | contains($kw)) or
            ((.tags // []) | map(ascii_downcase) | any(contains($kw)))
          )] | .[0] // empty' 2>/dev/null)

          if [ -n "$matched" ] && [ "$matched" != "null" ]; then
            echo "$matched" | jq -c --arg plugin "$plugin" --arg combo "$combo_key" '. + {"_reason": ("synergy with " + $plugin), "_combo": $combo}'
          fi
        done
      fi
    done
  done | jq -s -c 'unique_by(.name // .id)' 2>/dev/null || echo "[]"
}

# ============================================================================
# 스킬 설치
# ============================================================================

install_skill() {
  local skill_id="$1"

  if [ -z "$skill_id" ]; then
    echo "Error: skill ID required"
    echo "Usage: $0 install <skill-id>"
    return 1
  fi

  # npx 확인
  if ! check_npx > /dev/null 2>&1; then
    check_npx
    return 1
  fi

  echo "Installing skill: $skill_id"

  local install_result
  install_result=$(npx skills add "$skill_id" 2>&1)
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    # history.json에 기록
    if [ -f "$HISTORY_FILE" ]; then
      local timestamp
      timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      jq --arg skill "$skill_id" --arg ts "$timestamp" '
        .lastUpdated = $ts |
        .skills.installed[$skill] = {
          installedAt: $ts,
          source: "skills.sh",
          autoInstalled: false
        }
      ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi

    echo "Installed: $skill_id"
    echo "Skill is now available in Claude Code."
    return 0
  else
    echo "Error installing $skill_id:"
    echo "$install_result"
    return 1
  fi
}

# ============================================================================
# 상태 표시
# ============================================================================

show_status() {
  echo "=== Skill Scout Status ==="
  echo ""

  # 설치된 스킬
  local installed
  installed=$(get_installed_skills)
  local installed_count
  installed_count=$(echo "$installed" | jq 'length' 2>/dev/null || echo 0)

  echo "Installed Skills: $installed_count"
  if [ "$installed_count" -gt 0 ] 2>/dev/null; then
    echo "$installed" | jq -r '.[] | "  - " + .' 2>/dev/null
  fi
  echo ""

  # 마지막 동기화 시각
  if [ -f "$SKILLS_CACHE" ]; then
    local cache_mtime
    if [[ "$OSTYPE" == "darwin"* ]]; then
      cache_mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$SKILLS_CACHE" 2>/dev/null)
    else
      cache_mtime=$(stat -c "%y" "$SKILLS_CACHE" 2>/dev/null | cut -d'.' -f1)
    fi
    echo "Last Sync: $cache_mtime"
  else
    echo "Last Sync: never"
  fi
  echo ""

  # skills_sh 설정 요약
  local sh_enabled
  sh_enabled=$(read_config "enabled" "true")
  local auto_official
  auto_official=$(read_config "auto_install_official" "true")
  local cache_ttl
  cache_ttl=$(read_config "cache_ttl" "3600")
  local max_rec
  max_rec=$(read_config "max_recommendations" "5")

  echo "Config (skills_sh):"
  echo "  enabled: $sh_enabled"
  echo "  auto_install_official: $auto_official"
  echo "  cache_ttl: ${cache_ttl}s"
  echo "  max_recommendations: $max_rec"
  echo ""

  # 마지막 자동 설치 결과
  if [ -f "$INSTALL_LOG" ]; then
    echo "Last Auto-Install:"
    jq -r '
      "  timestamp: " + .timestamp,
      "  installed: " + (.installed | tostring),
      "  skipped: " + (.skipped | tostring),
      "  failed: " + (.failed | tostring)
    ' "$INSTALL_LOG" 2>/dev/null
  else
    echo "Last Auto-Install: none"
  fi
}

# ============================================================================
# CLI 인터페이스
# ============================================================================

case "$1" in
  fetch)
    fetch_catalog
    ;;
  auto)
    auto_install_official
    ;;
  recommend)
    recommend "${2:-5}"
    ;;
  search)
    search "$2"
    ;;
  combos)
    suggest_combos
    ;;
  install)
    install_skill "$2"
    ;;
  status)
    show_status
    ;;
  check-npx)
    check_npx
    ;;
  installed)
    get_installed_skills
    ;;
  *)
    echo "Usage: $0 {fetch|auto|recommend|search|combos|install|status|check-npx|installed}"
    echo ""
    echo "Commands:"
    echo "  fetch              - Fetch skills catalog from skills.sh API"
    echo "  auto               - Auto-install Anthropic official skills"
    echo "  recommend [count]  - Get top N recommended skills (default: 5)"
    echo "  search <query>     - Search skills by keyword"
    echo "  combos             - Suggest synergy skills based on installed plugins"
    echo "  install <skill-id> - Install a skill via npx"
    echo "  status             - Show skill scout status"
    echo "  check-npx          - Verify npx availability"
    echo "  installed          - List installed skills"
    ;;
esac
