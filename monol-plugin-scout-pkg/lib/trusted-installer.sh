#!/bin/bash
# Plugin Scout - 신뢰된 자동 설치 엔진
# 신뢰된 저자(Anthropic 등)의 공식 플러그인을 자동 설치

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
DATA_DIR="$PLUGIN_ROOT/data"

MARKETPLACE_FILE="$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"
CACHE_DIR="$DATA_DIR/.cache"
CACHE_FILE="$CACHE_DIR/trusted-catalog.json"
INSTALL_LOG="$DATA_DIR/.last-auto-install.json"
HISTORY_FILE="$DATA_DIR/history.json"
USAGE_FILE="$DATA_DIR/usage.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CONFIG_FILE="$PLUGIN_ROOT/config.yaml"

LOGGER="$PLUGIN_ROOT/lib/logger.sh"
PLUGIN_MANAGER="$PLUGIN_ROOT/lib/plugin-manager.sh"
PROJECT_ANALYZER="$PLUGIN_ROOT/lib/project-analyzer.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_log() {
  local level="$1"
  local msg="$2"
  if [ -f "$LOGGER" ]; then
    bash "$LOGGER" "$level" "$msg" "trusted-installer"
  fi
}

_log_event() {
  local event_type="$1"
  local event_data="$2"
  if [ -f "$LOGGER" ]; then
    bash "$LOGGER" event "$event_type" "$event_data"
  fi
}

# ---------------------------------------------------------------------------
# Config reading
# ---------------------------------------------------------------------------

# Read a value from config.yaml auto_install section
# Usage: read_config <key> [default]
read_config() {
  local key="$1"
  local default="$2"
  local value=""

  if [ -f "$CONFIG_FILE" ]; then
    value=$(grep "^  ${key}:" "$CONFIG_FILE" 2>/dev/null | sed "s/^  ${key}:[[:space:]]*//" | sed 's/[[:space:]]*$//')
  fi

  if [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Check if trusted auto-install is enabled
# Returns 0 if BOTH config.yaml and history.json agree, 1 otherwise
is_enabled() {
  # 1. Check config.yaml auto_install.enabled
  local config_enabled
  config_enabled=$(read_config "enabled" "false")
  if [ "$config_enabled" != "true" ]; then
    return 1
  fi

  # 2. Check history.json preferences.trustedAutoInstall
  if [ -f "$HISTORY_FILE" ] && command -v jq &> /dev/null; then
    local history_enabled
    history_enabled=$(jq -r '.preferences.trustedAutoInstall // false' "$HISTORY_FILE" 2>/dev/null)
    if [ "$history_enabled" != "true" ]; then
      return 1
    fi
  else
    # No history file or no jq → treat as disabled
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Trusted authors
# ---------------------------------------------------------------------------

# Get trusted authors list from config.yaml
# Returns JSON array, e.g. ["Anthropic"]
get_trusted_authors() {
  local line
  line=$(grep 'trusted_authors:' "$CONFIG_FILE" 2>/dev/null)
  if [ -z "$line" ]; then
    echo '["Anthropic"]'
    return
  fi

  # Extract array content: trusted_authors: ["Anthropic", "vercel"] → JSON
  local raw
  raw=$(echo "$line" | sed 's/.*\[/[/' | sed 's/\].*/]/')
  if echo "$raw" | jq '.' &>/dev/null; then
    echo "$raw"
  else
    echo '["Anthropic"]'
  fi
}

# ---------------------------------------------------------------------------
# Marketplace & installed plugins
# ---------------------------------------------------------------------------

# Parse marketplace.json and filter by trusted authors
# Returns JSON array of {name, description, author, category}
get_marketplace_plugins() {
  local marketplace_data=""

  if [ -f "$MARKETPLACE_FILE" ] && command -v jq &> /dev/null; then
    marketplace_data=$(cat "$MARKETPLACE_FILE" 2>/dev/null)
  fi

  # Fallback to cache if marketplace file not available
  if [ -z "$marketplace_data" ] || ! echo "$marketplace_data" | jq '.' &>/dev/null; then
    if [ -f "$CACHE_FILE" ]; then
      cat "$CACHE_FILE"
      return 0
    else
      # No marketplace data and no cache — exit silently
      echo "[]"
      return 0
    fi
  fi

  local trusted_authors
  trusted_authors=$(get_trusted_authors)

  # Filter plugins by trusted authors and project to {name, description, author, category}
  local filtered
  filtered=$(echo "$marketplace_data" | jq --argjson authors "$trusted_authors" '
    [.plugins // .[] | objects] | flatten |
    map(select(
      .author.name as $aname |
      ($authors | map(ascii_downcase) | index($aname | ascii_downcase)) != null
    )) |
    map({
      name: (.name // .id // "unknown"),
      description: (.description // ""),
      author: (.author.name // "unknown"),
      category: (.category // "general")
    })
  ' 2>/dev/null)

  if [ -z "$filtered" ] || ! echo "$filtered" | jq '.' &>/dev/null; then
    # Try alternate JSON structure (flat array)
    filtered=$(echo "$marketplace_data" | jq --argjson authors "$trusted_authors" '
      if type == "array" then . else [.] end |
      map(select(
        (.author.name // .author // "") as $aname |
        ($authors | map(ascii_downcase) | index($aname | ascii_downcase)) != null
      )) |
      map({
        name: (.name // .id // "unknown"),
        description: (.description // ""),
        author: (if .author | type == "object" then .author.name else (.author // "unknown") end),
        category: (.category // "general")
      })
    ' 2>/dev/null)
  fi

  if [ -z "$filtered" ] || ! echo "$filtered" | jq '.' &>/dev/null; then
    echo "[]"
    return 0
  fi

  # Cache for offline fallback
  local cache_catalog
  cache_catalog=$(read_config "cache_catalog" "true")
  if [ "$cache_catalog" = "true" ]; then
    mkdir -p "$CACHE_DIR"
    echo "$filtered" > "$CACHE_FILE"
  fi

  echo "$filtered"
}

# Get list of currently installed/enabled plugins
get_installed_plugins() {
  if command -v jq &> /dev/null && [ -f "$CLAUDE_SETTINGS" ]; then
    jq -r '.enabledPlugins // {} | keys[]' "$CLAUDE_SETTINGS" 2>/dev/null
  fi
}

# ---------------------------------------------------------------------------
# Language matching (LSP plugins)
# ---------------------------------------------------------------------------

# Check if an LSP plugin matches the current project language
# Returns 0 (match) or 1 (no match). Non-LSP plugins always return 0.
detect_language_match() {
  local plugin_name="$1"
  local project_types=""

  # Get project types from project-analyzer
  if [ -f "$PROJECT_ANALYZER" ]; then
    project_types=$(bash "$PROJECT_ANALYZER" types 2>/dev/null)
  fi

  case "$plugin_name" in
    typescript-lsp)
      echo "$project_types" | grep -qE '"nodejs"|"typescript"' && return 0
      return 1
      ;;
    pyright-lsp|python-lsp)
      echo "$project_types" | grep -q '"python"' && return 0
      return 1
      ;;
    gopls-lsp|go-lsp)
      echo "$project_types" | grep -q '"go"' && return 0
      return 1
      ;;
    rust-analyzer-lsp|rust-lsp)
      echo "$project_types" | grep -q '"rust"' && return 0
      return 1
      ;;
    jdtls-lsp|java-lsp)
      echo "$project_types" | grep -q '"java"' && return 0
      return 1
      ;;
    php-lsp)
      echo "$project_types" | grep -q '"php"' && return 0
      return 1
      ;;
    clangd-lsp|c-lsp|cpp-lsp)
      find . -maxdepth 3 -name "*.c" -o -name "*.cpp" -o -name "*.h" 2>/dev/null | head -1 | grep -q . && return 0
      return 1
      ;;
    swift-lsp)
      find . -maxdepth 3 -name "*.swift" 2>/dev/null | head -1 | grep -q . && return 0
      return 1
      ;;
    kotlin-lsp)
      find . -maxdepth 3 -name "*.kt" -o -name "*.kts" 2>/dev/null | head -1 | grep -q . && return 0
      return 1
      ;;
    csharp-lsp)
      find . -maxdepth 3 -name "*.cs" 2>/dev/null | head -1 | grep -q . && return 0
      return 1
      ;;
    lua-lsp)
      find . -maxdepth 3 -name "*.lua" 2>/dev/null | head -1 | grep -q . && return 0
      return 1
      ;;
    *)
      # Non-LSP plugins always match
      return 0
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Conflict detection
# ---------------------------------------------------------------------------

# Check for conflicting plugins already installed
# Returns 0 (no conflict) or 1 (conflict detected)
check_conflicts() {
  local plugin_name="$1"
  local installed
  installed=$(get_installed_plugins)

  # Define conflict groups
  local -A conflict_groups
  conflict_groups=(
    ["prettier-format"]="formatters"
    ["eslint-fix"]="formatters"
    ["biome-format"]="formatters"
    ["eslint-lsp"]="linters"
    ["biome-lsp"]="linters"
    ["commit-commands"]="git"
    ["git-helper"]="git"
    ["conventional-commits"]="git"
  )

  local plugin_group="${conflict_groups[$plugin_name]}"
  if [ -z "$plugin_group" ]; then
    # Plugin is not in any conflict group
    return 0
  fi

  # Check if another plugin from the same group is installed
  for key in "${!conflict_groups[@]}"; do
    if [ "$key" = "$plugin_name" ]; then
      continue
    fi
    if [ "${conflict_groups[$key]}" = "$plugin_group" ]; then
      # Check if this conflicting plugin is installed
      if echo "$installed" | grep -qE "^${key}(@|$)"; then
        return 1
      fi
    fi
  done

  return 0
}

# ---------------------------------------------------------------------------
# Filter pipeline
# ---------------------------------------------------------------------------

# Main filter: get marketplace plugins → exclude installed → apply LSP/conflict filters
# Returns JSON array of candidate plugins
filter_relevant() {
  local marketplace_plugins
  marketplace_plugins=$(get_marketplace_plugins)

  if [ "$marketplace_plugins" = "[]" ] || [ -z "$marketplace_plugins" ]; then
    echo "[]"
    return
  fi

  local installed
  installed=$(get_installed_plugins)

  local lsp_filter
  lsp_filter=$(read_config "lsp_language_filter" "true")

  local conflict_check
  conflict_check=$(read_config "check_conflicts" "true")

  local candidates="[]"

  # Iterate marketplace plugins
  local count
  count=$(echo "$marketplace_plugins" | jq 'length' 2>/dev/null)
  if [ -z "$count" ] || [ "$count" = "0" ]; then
    echo "[]"
    return
  fi

  local i=0
  while [ "$i" -lt "$count" ]; do
    local plugin_json
    plugin_json=$(echo "$marketplace_plugins" | jq ".[$i]" 2>/dev/null)
    local plugin_name
    plugin_name=$(echo "$plugin_json" | jq -r '.name' 2>/dev/null)

    # Skip if already installed
    if echo "$installed" | grep -qE "^${plugin_name}(@|$)"; then
      i=$((i + 1))
      continue
    fi

    # Skip if LSP and language doesn't match
    if [ "$lsp_filter" = "true" ]; then
      if ! detect_language_match "$plugin_name"; then
        i=$((i + 1))
        continue
      fi
    fi

    # Skip if conflict detected
    if [ "$conflict_check" = "true" ]; then
      if ! check_conflicts "$plugin_name"; then
        i=$((i + 1))
        continue
      fi
    fi

    # Add to candidates
    candidates=$(echo "$candidates" | jq --argjson p "$plugin_json" '. + [$p]' 2>/dev/null)

    i=$((i + 1))
  done

  echo "$candidates"
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

# Install a single plugin via plugin-manager.sh
execute_install() {
  local plugin_name="$1"
  local marketplace
  marketplace=$(read_config "marketplace" "claude-plugins-official")

  if [ -f "$PLUGIN_MANAGER" ]; then
    bash "$PLUGIN_MANAGER" install "${plugin_name}@${marketplace}" "trusted-auto-install" 2>&1
    return $?
  else
    _log "error" "plugin-manager.sh not found"
    return 1
  fi
}

# Record install result in history.json and usage.json
record_install() {
  local plugin_name="$1"
  local status="$2"  # success or failure
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local date_only
  date_only=$(date +"%Y-%m-%d")

  # Add to trustedInstallLog in history.json
  if [ -f "$HISTORY_FILE" ] && command -v jq &> /dev/null; then
    jq --arg plugin "$plugin_name" \
       --arg status "$status" \
       --arg ts "$timestamp" \
       --arg date "$date_only" \
       '
       .lastUpdated = $ts |
       .trustedInstallLog = ((.trustedInstallLog // []) + [{
         plugin: $plugin,
         status: $status,
         timestamp: $ts,
         date: $date,
         source: "trusted-auto-install"
       }])
       ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
  fi

  # Add to usage.json if success
  if [ "$status" = "success" ] && [ -f "$USAGE_FILE" ] && command -v jq &> /dev/null; then
    jq --arg plugin "$plugin_name" \
       --arg date "$date_only" \
       --arg ts "$timestamp" \
       '
       .lastUpdated = $ts |
       .plugins[$plugin] = (.plugins[$plugin] // {
         installed: $date,
         usageCount: 0,
         lastUsed: null,
         source: "trusted-auto-install"
       })
       ' "$USAGE_FILE" > "$USAGE_FILE.tmp" && mv "$USAGE_FILE.tmp" "$USAGE_FILE"
  fi

  _log_event "trusted_install" "{\"plugin\":\"$plugin_name\",\"status\":\"$status\"}"
}

# ---------------------------------------------------------------------------
# New release detection
# ---------------------------------------------------------------------------

# Compare cached catalog with current to detect new plugins
detect_new_releases() {
  if [ ! -f "$CACHE_FILE" ]; then
    echo "[]"
    return
  fi

  local old_cache
  old_cache=$(cat "$CACHE_FILE" 2>/dev/null)
  if [ -z "$old_cache" ] || ! echo "$old_cache" | jq '.' &>/dev/null; then
    echo "[]"
    return
  fi

  local current
  current=$(get_marketplace_plugins)
  if [ -z "$current" ] || ! echo "$current" | jq '.' &>/dev/null; then
    echo "[]"
    return
  fi

  # Find plugins in current that were not in old cache
  local new_releases
  new_releases=$(jq -n --argjson old "$old_cache" --argjson cur "$current" '
    ($old | map(.name)) as $old_names |
    [$cur[] | select(.name as $n | ($old_names | index($n)) == null)]
  ' 2>/dev/null)

  if [ -z "$new_releases" ] || ! echo "$new_releases" | jq '.' &>/dev/null; then
    echo "[]"
  else
    echo "$new_releases"
  fi
}

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

# Write install report to .last-auto-install.json
write_install_report() {
  local installed="$1"
  local skipped="$2"
  local new_releases="$3"
  local errors="$4"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local installed_count
  installed_count=$(echo "$installed" | jq 'length' 2>/dev/null || echo "0")
  local skipped_count
  skipped_count=$(echo "$skipped" | jq 'length' 2>/dev/null || echo "0")
  local new_count
  new_count=$(echo "$new_releases" | jq 'length' 2>/dev/null || echo "0")

  jq -n \
    --arg ts "$timestamp" \
    --argjson installed "$installed" \
    --argjson skipped "$skipped" \
    --argjson newReleases "$new_releases" \
    --argjson errors "$errors" \
    --arg summary "Installed ${installed_count}, Skipped ${skipped_count}, New ${new_count}" \
    '{
      timestamp: $ts,
      installed: $installed,
      skipped: $skipped,
      newReleases: $newReleases,
      errors: $errors,
      summary: $summary
    }' > "$INSTALL_LOG"
}

# ---------------------------------------------------------------------------
# Main orchestrators
# ---------------------------------------------------------------------------

# Run: full auto-install cycle
run() {
  # 1. Check enabled
  if ! is_enabled; then
    _log "info" "Trusted auto-install is disabled. Use '/scout trusted-install on' to enable."
    return 0
  fi

  # 2. Ensure cache directory
  mkdir -p "$CACHE_DIR"

  # 3. Detect new releases (save old cache before refresh)
  local new_releases="[]"
  local detect_new
  detect_new=$(read_config "detect_new_releases" "true")
  if [ "$detect_new" = "true" ]; then
    new_releases=$(detect_new_releases)
  fi

  # 4. Filter relevant candidates
  local candidates
  candidates=$(filter_relevant)
  if [ -z "$candidates" ] || [ "$candidates" = "[]" ]; then
    write_install_report "[]" "[]" "$new_releases" "[]"
    _log "info" "No new trusted plugins to install"
    return 0
  fi

  # 5. Install each candidate
  local installed="[]"
  local skipped="[]"
  local errors="[]"
  local count
  count=$(echo "$candidates" | jq 'length' 2>/dev/null)

  local i=0
  while [ "$i" -lt "${count:-0}" ]; do
    local plugin_name
    plugin_name=$(echo "$candidates" | jq -r ".[$i].name" 2>/dev/null)

    if [ -z "$plugin_name" ] || [ "$plugin_name" = "null" ]; then
      i=$((i + 1))
      continue
    fi

    local result
    result=$(execute_install "$plugin_name" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
      record_install "$plugin_name" "success"
      installed=$(echo "$installed" | jq --arg p "$plugin_name" '. + [$p]' 2>/dev/null)
      _log "info" "Installed trusted plugin: $plugin_name"
    else
      record_install "$plugin_name" "failure"
      errors=$(echo "$errors" | jq --arg p "$plugin_name" --arg e "$result" '. + [{plugin: $p, error: $e}]' 2>/dev/null)
      _log "warn" "Failed to install: $plugin_name — $result"
    fi

    i=$((i + 1))
  done

  # 6. Write report
  write_install_report "$installed" "$skipped" "$new_releases" "$errors"

  # 7. Log summary
  local installed_count
  installed_count=$(echo "$installed" | jq 'length' 2>/dev/null || echo "0")
  local error_count
  error_count=$(echo "$errors" | jq 'length' 2>/dev/null || echo "0")
  local new_count
  new_count=$(echo "$new_releases" | jq 'length' 2>/dev/null || echo "0")

  _log "info" "Trusted auto-install complete: ${installed_count} installed, ${error_count} errors, ${new_count} new releases"
}

# Check: dry-run mode (no installation)
check() {
  echo "=== Trusted Auto-Install Check (Dry Run) ==="
  echo ""

  # Status
  if is_enabled; then
    echo "Status: ENABLED"
  else
    echo "Status: DISABLED"
  fi
  echo ""

  # Trusted authors
  local authors
  authors=$(get_trusted_authors)
  echo "Trusted Authors: $(echo "$authors" | jq -r 'join(", ")' 2>/dev/null)"
  echo ""

  # Candidates
  local candidates
  candidates=$(filter_relevant)
  local count
  count=$(echo "$candidates" | jq 'length' 2>/dev/null || echo "0")

  echo "Candidates for installation: $count"
  if [ "$count" != "0" ] && [ "$count" != "" ]; then
    echo "$candidates" | jq -r '.[] | "  - \(.name) (\(.author)) — \(.description)"' 2>/dev/null
  fi
  echo ""

  # New releases
  local detect_new
  detect_new=$(read_config "detect_new_releases" "true")
  if [ "$detect_new" = "true" ]; then
    local new_releases
    new_releases=$(detect_new_releases)
    local new_count
    new_count=$(echo "$new_releases" | jq 'length' 2>/dev/null || echo "0")

    echo "New releases since last check: $new_count"
    if [ "$new_count" != "0" ] && [ "$new_count" != "" ]; then
      echo "$new_releases" | jq -r '.[] | "  - \(.name) (\(.author)) — \(.description)"' 2>/dev/null
    fi
  fi
  echo ""

  # Installed plugins count
  local installed_count
  installed_count=$(get_installed_plugins | wc -l | tr -d ' ')
  echo "Currently installed plugins: $installed_count"
}

# Enable trusted auto-install in both config.yaml and history.json
enable() {
  # Update config.yaml
  if [ -f "$CONFIG_FILE" ]; then
    if grep -q "^  enabled:" "$CONFIG_FILE"; then
      sed -i.bak 's/^  enabled:.*/  enabled: true/' "$CONFIG_FILE"
      rm -f "${CONFIG_FILE}.bak"
    fi
  fi

  # Update history.json
  if [ -f "$HISTORY_FILE" ] && command -v jq &> /dev/null; then
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg ts "$timestamp" '
      .lastUpdated = $ts |
      .preferences.trustedAutoInstall = true
    ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
  fi

  _log "info" "Trusted auto-install enabled"
  _log_event "trusted_install_toggle" "{\"action\":\"enable\"}"
  echo "Trusted auto-install: ENABLED"
}

# Disable trusted auto-install in both config.yaml and history.json
disable() {
  # Update config.yaml
  if [ -f "$CONFIG_FILE" ]; then
    if grep -q "^  enabled:" "$CONFIG_FILE"; then
      sed -i.bak 's/^  enabled:.*/  enabled: false/' "$CONFIG_FILE"
      rm -f "${CONFIG_FILE}.bak"
    fi
  fi

  # Update history.json
  if [ -f "$HISTORY_FILE" ] && command -v jq &> /dev/null; then
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg ts "$timestamp" '
      .lastUpdated = $ts |
      .preferences.trustedAutoInstall = false
    ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
  fi

  _log "info" "Trusted auto-install disabled"
  _log_event "trusted_install_toggle" "{\"action\":\"disable\"}"
  echo "Trusted auto-install: DISABLED"
}

# ---------------------------------------------------------------------------
# CLI interface
# ---------------------------------------------------------------------------

case "$1" in
  run)
    run
    ;;
  check)
    check
    ;;
  status)
    cat "$INSTALL_LOG" 2>/dev/null || echo "No install log found"
    ;;
  enable)
    enable
    ;;
  disable)
    disable
    ;;
  *)
    echo "Usage: $0 {run|check|status|enable|disable}"
    echo ""
    echo "Commands:"
    echo "  run       Execute trusted auto-install (install missing trusted plugins)"
    echo "  check     Dry-run: show what would be installed (no changes)"
    echo "  status    Show last auto-install report"
    echo "  enable    Enable trusted auto-install (config + history)"
    echo "  disable   Disable trusted auto-install (config + history)"
    echo ""
    echo "Config: config.yaml → auto_install section"
    echo "Log:    $INSTALL_LOG"
    ;;
esac
