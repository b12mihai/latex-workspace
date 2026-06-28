#!/bin/bash
# Multi-line status line for Claude Code.
# Reads the status JSON from stdin and prints a two-line status:
#   Line 1: [Model]  folder | branch
#   Line 2: <context bar> NN% | $cost | duration

export LC_ALL=C
input=$(cat)

# --- Extract fields from the status JSON --------------------------------------
model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')

dir_name=$(basename "$current_dir")

# --- Git branch ---------------------------------------------------------------
branch=""
if git -C "$current_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)
fi

# --- Context window usage % ---------------------------------------------------
# Pull the most recent assistant usage entry from the transcript and sum the
# token counts that occupy the context window.
# Context window size. Defaults to 1,000,000 (1M-context models); override via
# the CLAUDE_CTX_LIMIT env var for sessions on a 200k window.
ctx_limit=${CLAUDE_CTX_LIMIT:-1000000}
pct=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    tokens=$(jq -s '
        [ .[] | select(.message.usage != null) ] | last | .message.usage
        | ((.input_tokens // 0)
           + (.cache_read_input_tokens // 0)
           + (.cache_creation_input_tokens // 0))
    ' "$transcript" 2>/dev/null)
    [ -z "$tokens" ] && tokens=0
    [ "$tokens" = "null" ] && tokens=0
    pct=$(( tokens * 100 / ctx_limit ))
    [ "$pct" -gt 100 ] && pct=100
fi

# --- Build the progress bar ---------------------------------------------------
bar_width=10
filled=$(( pct * bar_width / 100 ))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
empty=$(( bar_width - filled ))

bar=""
if [ "$filled" -gt 0 ]; then
    bar+=$'\033[42m'                       # green background
    bar+=$(printf '%*s' "$filled" '')
    bar+=$'\033[0m'
fi
if [ "$empty" -gt 0 ]; then
    bar+=$'\033[2;32m'                      # dim green dotted fill
    bar+=$(printf '\xe2\x96\x91%.0s' $(seq 1 "$empty"))
    bar+=$'\033[0m'
fi

# --- Format duration ----------------------------------------------------------
secs=$(( duration_ms / 1000 ))
h=$(( secs / 3600 ))
m=$(( (secs % 3600) / 60 ))
s=$(( secs % 60 ))
if [ "$h" -gt 0 ]; then
    dur="${h}h ${m}m"
elif [ "$m" -gt 0 ]; then
    dur="${m}m ${s}s"
else
    dur="${s}s"
fi

# --- Format cost --------------------------------------------------------------
cost_fmt=$(printf '%.2f' "$cost")

# --- Colors -------------------------------------------------------------------
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
DIM=$'\033[2m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

# --- Emit ---------------------------------------------------------------------
# Line 1
printf '%s[%s]%s 📁 %s%s%s' "$CYAN" "$model" "$RESET" "$BOLD" "$dir_name" "$RESET"
if [ -n "$branch" ]; then
    printf ' %s|%s 🌿 %s' "$DIM" "$RESET" "$branch"
fi
printf '\n'
# Line 2
printf '%s %d%% %s|%s %s$%s%s %s|%s ⏰ %s' \
    "$bar" "$pct" \
    "$DIM" "$RESET" \
    "$YELLOW" "$cost_fmt" "$RESET" \
    "$DIM" "$RESET" \
    "$dur"
