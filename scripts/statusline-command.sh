#!/usr/bin/env bash
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dirname=$(basename "$dir")

# Extract just the base model name (Opus/Sonnet/Haiku)
model=$(echo "$input" | jq -r '.model.display_name // ""' | awk '{print $1}')

# Context window usage
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Rate limits
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Session info
session_id=$(echo "$input" | jq -r '.session_id // ""')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Format seconds into human-readable duration
format_duration() {
  local seconds=$1
  if [ "$seconds" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$((seconds / 86400))
  local hours=$(( (seconds % 86400) / 3600 ))
  local mins=$(( (seconds % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d ${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# Calculate burn rate and projection
calc_burn_info() {
  local used_pct=$1
  local reset_epoch=$2
  local window_seconds=$3
  local now
  now=$(date +%s)

  local time_to_reset=$((reset_epoch - now))
  local reset_fmt
  reset_fmt=$(format_duration "$time_to_reset")

  local window_start=$((reset_epoch - window_seconds))
  local elapsed=$((now - window_start))

  if [ "$elapsed" -le 0 ] || [ "$(awk "BEGIN {print ($used_pct <= 0)}")" = "1" ]; then
    echo "0%/h safe (${reset_fmt})"
    return
  fi

  local rate
  rate=$(awk "BEGIN {printf \"%.1f\", $used_pct / ($elapsed / 3600.0)}")
  rate=$(echo "$rate" | sed 's/\.0$//')

  local rate_per_sec
  rate_per_sec=$(awk "BEGIN {print $used_pct / $elapsed}")

  if [ "$(awk "BEGIN {print ($rate_per_sec <= 0)}")" = "1" ]; then
    echo "${rate}%/h safe (${reset_fmt})"
    return
  fi

  local remaining_pct
  remaining_pct=$(awk "BEGIN {print 100 - $used_pct}")
  local time_to_full
  time_to_full=$(awk "BEGIN {printf \"%.0f\", $remaining_pct / $rate_per_sec}")

  if [ "$time_to_full" -ge "$time_to_reset" ]; then
    echo "${rate}%/h safe (${reset_fmt})"
  else
    local full_fmt
    full_fmt=$(format_duration "$time_to_full")
    echo "${rate}%/h ~${full_fmt} (${reset_fmt})"
  fi
}

# ── Original statusline output (unchanged) ──────────────────────────
parts=""
[ -n "$dirname" ] && parts="📁 ${dirname}"

if [ -n "$total" ]; then
  used=$(awk "BEGIN {printf \"%.0f\", $cache_read + $cache_create + $input_tokens}")
  used_k=$(awk "BEGIN {printf \"%.1fk\", $used/1000}")
  total_k=$(awk "BEGIN {printf \"%.0fk\", $total/1000}")
  pct=$(awk "BEGIN {printf \"%.0f\", $used * 100 / $total}")
  parts="${parts} | 📊 ${used_k}/${total_k} (${pct}%)"
fi

if [ -n "$five_h_pct" ] || [ -n "$seven_d_pct" ]; then
  limits=""
  if [ -n "$five_h_pct" ]; then
    five_h_rounded=$(awk "BEGIN {printf \"%.0f\", $five_h_pct}")
    five_h_info=$(calc_burn_info "$five_h_pct" "$five_h_reset" 18000)
    limits="5h: ${five_h_rounded}% ${five_h_info}"
  fi
  if [ -n "$seven_d_pct" ]; then
    seven_d_rounded=$(awk "BEGIN {printf \"%.0f\", $seven_d_pct}")
    seven_d_info=$(calc_burn_info "$seven_d_pct" "$seven_d_reset" 604800)
    [ -n "$limits" ] && limits="${limits}, "
    limits="${limits}7d: ${seven_d_rounded}% ${seven_d_info}"
  fi
  parts="${parts} | 🔒 ${limits}"
fi

[ -n "$model" ] && parts="${parts} | 🚀 ${model}"

echo "$parts"

# ── Write per-session JSON for ClaudeStatusWidget ────────────────────
if [ -n "$session_id" ]; then
  SESSION_DIR="$HOME/.claude/session-status"
  mkdir -p "$SESSION_DIR"
  NOW=$(date +%s)

  # Build rate_limits JSON fragment (may be empty)
  rl_json=""
  if [ -n "$five_h_pct" ] && [ -n "$seven_d_pct" ]; then
    rl_json=$(cat <<RLJSON
  "rate_limits": {
    "five_hour": {
      "used_percentage": $five_h_pct,
      "resets_at": $five_h_reset
    },
    "seven_day": {
      "used_percentage": $seven_d_pct,
      "resets_at": $seven_d_reset
    }
  },
RLJSON
)
  fi

  cat > "$SESSION_DIR/${session_id}.json" <<SESSIONEOF
{
  "session_id": "$session_id",
  "pid": $PPID,
  "folder_name": "$dirname",
  "folder_path": "$dir",
  "model": "$model",
  "context": {
    "used_tokens": ${used:-0},
    "total_tokens": ${total:-0},
    "used_percentage": ${pct:-0}
  },
  $rl_json
  "cost_usd": $cost,
  "lines_added": $lines_added,
  "lines_removed": $lines_removed,
  "timestamp": $NOW
}
SESSIONEOF
fi

# ── Write health file for Rocket watchdog (existing behavior) ────────
NOW=$(date +%s)
HEALTH_FILE="$HOME/.rocket/mark2-health.json"
mkdir -p "$(dirname "$HEALTH_FILE")"
cat > "$HEALTH_FILE" <<EOF
{
  "context_pct": ${pct:-0},
  "session_id": "$session_id",
  "model": "$model",
  "cost_usd": $cost,
  "timestamp": $NOW
}
EOF
