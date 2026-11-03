#!/bin/bash
# PostToolUse: podczas /implement uruchamia linter na edytowanym pliku .swift (jeśli skonfigurowany).
AIW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/aiw"
input="$(cat)"

"$AIW" is-active || exit 0
lint="$("$AIW" lint-cmd)"
[ -z "$lint" ] && exit 0

path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
case "$path" in *.swift) ;; *) exit 0 ;; esac
[ -f "$path" ] || exit 0

out="$(cd "$("$AIW" root)" && eval "$lint \"\$path\"" 2>&1)"
if [ $? -ne 0 ] || grep -qE "(error|warning):" <<<"$out"; then
  echo "Linter zgłosił problemy w $path — popraw je:" >&2
  head -30 <<<"$out" >&2
  exit 2
fi
exit 0
