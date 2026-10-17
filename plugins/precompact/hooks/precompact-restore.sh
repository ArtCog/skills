#!/usr/bin/env bash
# SessionStart (matcher: compact): feeds the /precompact note back right after compaction.
#
# Only the agent can decide what matters, but at compaction time it is gone: PreCompact and
# PostCompact cannot add context. So the agent writes ahead (/precompact) and this hook reads.
#
# The note lives in this session's scratchpad: <tmp>/claude/<project slug>/<session_id>/scratchpad/.
# Matching on session_id is strict on purpose: a "newest file" fallback once pulled a parallel
# session's note, and someone else's stopping point is worse than none. Compaction keeps session_id.

payload=$(cat)

session=$(printf '%s' "$payload" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')
[ -n "$session" ] || exit 0

root="${TMPDIR:-/tmp}"
root="${root%/}/claude"
[ -d "$root" ] || exit 0

file=$(find "$root" -maxdepth 4 -path "*/$session/scratchpad/PRECOMPACT.md" 2>/dev/null | head -1)
[ -n "$file" ] || exit 0

modified=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || date +%s)
mins=$(( ( $(date +%s) - modified ) / 60 ))
warn=""
[ "$mins" -ge 90 ] && warn=" ВНИМАНИЕ: записано $mins мин назад, возможно ещё до прошлого сжатия. Сверить с диском, прежде чем верить."

# JSON-escape the note: backslashes, quotes, tabs, carriage returns, newlines (portable awk, no GNU sed).
body=$(awk '{ gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); printf "%s\\n", $0 }' "$file")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Точка остановки до сжатия, записана скиллом /precompact.%s Здесь то, чего нет в саммари: тупики, решения пользователя дословно, точное место остановки. Продолжать отсюда, не пересказывать сделанное.\\n\\n%s"}}\n' "$warn" "$body"
