#!/bin/bash
# trust-manager.sh — Trust author management module
# Manages the trusted_authors list in config.yaml for auto-install decisions.
# Can be used as CLI or sourced by other scripts.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
DATA_DIR="$PLUGIN_ROOT/data"
CONFIG_FILE="$PLUGIN_ROOT/config.yaml"
EVENTS_LOG="$DATA_DIR/logs/events.jsonl"
HISTORY_FILE="$DATA_DIR/history.json"
LOGGER="$PLUGIN_ROOT/lib/logger.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

read_config() {
  local key="$1"
  grep "^${key}:" "$CONFIG_FILE" 2>/dev/null | sed "s/^${key}:[[:space:]]*//"
}

_get_trusted_line() {
  grep 'trusted_authors:' "$CONFIG_FILE" 2>/dev/null
}

_parse_trusted_authors() {
  # Parse trusted_authors: ["Anthropic", "vercel"] → one author per line
  local line
  line=$(_get_trusted_line)
  if [ -z "$line" ]; then
    return
  fi
  echo "$line" \
    | sed 's/.*\[//' \
    | sed 's/\].*//' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed 's/^"//;s/"$//' \
    | grep -v '^$'
}

_write_trusted_authors() {
  # Accepts authors as arguments, writes them back to config.yaml
  local authors=("$@")
  local json_array=""
  for a in "${authors[@]}"; do
    if [ -n "$json_array" ]; then
      json_array="${json_array}, \"${a}\""
    else
      json_array="\"${a}\""
    fi
  done
  local new_line="  trusted_authors: [${json_array}]"

  if grep -q 'trusted_authors:' "$CONFIG_FILE"; then
    sed -i.bak "s|.*trusted_authors:.*|${new_line}|" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  else
    # Append under auto_install section
    echo "$new_line" >> "$CONFIG_FILE"
  fi
}

_log_event() {
  local action="$1"
  local detail="$2"
  if [ -x "$LOGGER" ]; then
    bash "$LOGGER" log "trust" "$action" "$detail"
  elif [ -f "$LOGGER" ]; then
    bash "$LOGGER" log "trust" "$action" "$detail"
  else
    # Fallback: write directly to events.jsonl
    mkdir -p "$(dirname "$EVENTS_LOG")"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"${ts}\",\"source\":\"trust-manager\",\"action\":\"${action}\",\"detail\":\"${detail}\"}" >> "$EVENTS_LOG"
  fi
}

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

add_trusted() {
  local author="$1"
  if [ -z "$author" ]; then
    echo "Error: author name required"
    return 1
  fi

  # Strip leading @ if present
  author="${author#@}"

  # Check if already trusted
  local existing
  existing=$(_parse_trusted_authors)
  if echo "$existing" | grep -qx "$author"; then
    echo "\"${author}\" is already in the trusted authors list."
    return 0
  fi

  # Build new list
  local authors=()
  while IFS= read -r a; do
    [ -n "$a" ] && authors+=("$a")
  done <<< "$existing"
  authors+=("$author")

  _write_trusted_authors "${authors[@]}"
  _log_event "trust_add" "Added trusted author: ${author}"
  echo "Added \"${author}\" to trusted authors."
}

remove_trusted() {
  local author="$1"
  if [ -z "$author" ]; then
    echo "Error: author name required"
    return 1
  fi

  # Strip leading @ if present
  author="${author#@}"

  # Protect Anthropic
  if [ "$author" = "Anthropic" ] || [ "$author" = "anthropic" ]; then
    echo "Error: \"Anthropic\" is a protected author and cannot be removed."
    return 1
  fi

  local existing
  existing=$(_parse_trusted_authors)
  if ! echo "$existing" | grep -qx "$author"; then
    echo "\"${author}\" is not in the trusted authors list."
    return 1
  fi

  # Build new list without the target
  local authors=()
  while IFS= read -r a; do
    if [ -n "$a" ] && [ "$a" != "$author" ]; then
      authors+=("$a")
    fi
  done <<< "$existing"

  _write_trusted_authors "${authors[@]}"
  _log_event "trust_remove" "Removed trusted author: ${author}"
  echo "Removed \"${author}\" from trusted authors."
}

list_trusted() {
  echo "=== Trusted Authors ==="
  local authors
  authors=$(_parse_trusted_authors)
  if [ -z "$authors" ]; then
    echo "  (none)"
    return 0
  fi
  local i=1
  while IFS= read -r a; do
    if [ -n "$a" ]; then
      echo "  ${i}. ${a}"
      i=$((i + 1))
    fi
  done <<< "$authors"
}

is_trusted() {
  local author="$1"
  if [ -z "$author" ]; then
    return 1
  fi

  # Strip leading @ if present
  author="${author#@}"

  local existing
  existing=$(_parse_trusted_authors)
  if echo "$existing" | grep -qx "$author"; then
    return 0
  else
    return 1
  fi
}

export_audit() {
  local export_file="$DATA_DIR/trust-audit-export.json"
  mkdir -p "$DATA_DIR"

  # Collect trust-related events from events.jsonl
  local trust_events="[]"
  if [ -f "$EVENTS_LOG" ]; then
    trust_events=$(grep -E '"trust|trusted|trust_add|trust_remove"' "$EVENTS_LOG" 2>/dev/null \
      | jq -s '.' 2>/dev/null || echo "[]")
  fi

  # Collect trustedInstallLog from history.json
  local trusted_install_log="[]"
  if [ -f "$HISTORY_FILE" ]; then
    trusted_install_log=$(jq '.trustedInstallLog // []' "$HISTORY_FILE" 2>/dev/null || echo "[]")
  fi

  # Collect current trusted authors
  local current_authors
  current_authors=$(_parse_trusted_authors)
  local authors_json="[]"
  if [ -n "$current_authors" ]; then
    authors_json=$(echo "$current_authors" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
  fi

  # Build export JSON
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -n \
    --arg ts "$ts" \
    --argjson events "$trust_events" \
    --argjson installs "$trusted_install_log" \
    --argjson authors "$authors_json" \
    '{
      exported_at: $ts,
      current_trusted_authors: $authors,
      trust_events: $events,
      trusted_install_log: $installs
    }' > "$export_file"

  echo "Audit exported to: ${export_file}"
}

# ---------------------------------------------------------------------------
# CLI interface
# ---------------------------------------------------------------------------

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "$1" in
    add)
      add_trusted "$2"
      ;;
    remove)
      remove_trusted "$2"
      ;;
    list)
      list_trusted
      ;;
    check)
      is_trusted "$2" && echo "trusted" || echo "not trusted"
      ;;
    export)
      export_audit
      ;;
    *)
      echo "Usage: $0 {add|remove|list|check|export} [author]"
      echo ""
      echo "Commands:"
      echo "  add <author>      Add author to trusted list"
      echo "  remove <author>   Remove author from trusted list"
      echo "  list              Show all trusted authors"
      echo "  check <author>    Check if author is trusted"
      echo "  export            Export full trust audit log"
      exit 1
      ;;
  esac
fi
