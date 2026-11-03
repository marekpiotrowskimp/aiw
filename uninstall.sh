#!/bin/bash
# Usuwa komendy, hooki i plugin aiw. Dane projektów (~/.claude/ai-workflow-data) zostają.
set -euo pipefail

CLAUDE="$HOME/.claude"
SETTINGS="$CLAUDE/settings.json"
OPENCODE="$HOME/.config/opencode"

for c in spec implement audit finish; do
  [ -L "$CLAUDE/commands/$c.md" ] && rm "$CLAUDE/commands/$c.md" && echo "Usunięto $CLAUDE/commands/$c.md"
  [ -L "$CLAUDE/skills/$c" ] && rm "$CLAUDE/skills/$c" && echo "Usunięto $CLAUDE/skills/$c"
  f="$OPENCODE/commands/$c.md"
  [ -f "$f" ] && grep -q "# aiw:generated" "$f" && rm "$f" && echo "Usunięto $f"
done
[ -L "$OPENCODE/plugins/aiw.js" ] && rm "$OPENCODE/plugins/aiw.js" && echo "Usunięto $OPENCODE/plugins/aiw.js"
[ -L "$CLAUDE/ai-workflow" ] && rm "$CLAUDE/ai-workflow" && echo "Usunięto $CLAUDE/ai-workflow"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak-aiw-$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  jq '
    def strip: map(select(([.hooks[]?.command] | map(test("ai-workflow/hooks")) | any) | not));
    if .hooks then .hooks |= with_entries(.value |= strip) else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "Usunięto hooki aiw z $SETTINGS"
fi
