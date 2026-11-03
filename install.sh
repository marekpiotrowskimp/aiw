#!/bin/bash
# Instaluje aiw wyłącznie w Twojej konfiguracji. Repozytoria projektów pozostają nietknięte.
#
# Claude Code:
#   ~/.claude/ai-workflow            -> symlink do tego repo (skrypty, hooki)
#   ~/.claude/commands/<cmd>.md      -> symlinki: /spec /implement /audit /finish
#   ~/.claude/settings.json          -> dopisane hooki (nieaktywne poza /implement)
# OpenCode (jeśli zainstalowany):
#   ~/.config/opencode/commands/<cmd>.md  -> wygenerowane z commands/*.md
#   ~/.config/opencode/plugins/aiw.js     -> symlink do adaptera (te same hooki)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
SETTINGS="$CLAUDE/settings.json"
OPENCODE="$HOME/.config/opencode"
COMMANDS="spec implement audit finish"
MARKER="# aiw:generated"

command -v jq >/dev/null || { echo "Wymagany jq"; exit 1; }

link() {
  local target="$1" name="$2"
  if [ -e "$name" ] && [ ! -L "$name" ]; then
    echo "  Pomijam $name — istnieje i nie jest symlinkiem."
    return 1
  fi
  ln -sfn "$target" "$name"
  echo "  $name"
}

chmod +x "$REPO/bin/aiw" "$REPO/hooks/"*.sh
mkdir -p "$CLAUDE/commands" "$CLAUDE/ai-workflow-data/projects"

echo "Claude Code:"
link "$REPO" "$CLAUDE/ai-workflow"
for c in $COMMANDS; do link "$REPO/commands/$c.md" "$CLAUDE/commands/$c.md" || true; done

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-aiw-$(date +%Y%m%d%H%M%S)"
H='$HOME/.claude/ai-workflow/hooks'
tmp="$(mktemp)"
jq --arg h "$H" '
  def strip: map(select(([.hooks[]?.command] | map(test("ai-workflow/hooks")) | any) | not));
  .hooks //= {}
  | .hooks.PreToolUse  = ((.hooks.PreToolUse  // []) | strip) + [{matcher: "Edit|Write|MultiEdit|NotebookEdit|Bash", hooks: [{type: "command", command: ($h + "/pre-tool-use.sh")}]}]
  | .hooks.PostToolUse = ((.hooks.PostToolUse // []) | strip) + [{matcher: "Edit|Write|MultiEdit", hooks: [{type: "command", command: ($h + "/post-tool-use.sh")}]}]
  | .hooks.Stop        = ((.hooks.Stop        // []) | strip) + [{hooks: [{type: "command", command: ($h + "/stop.sh"), timeout: 1800, statusMessage: "aiw: build i testy..."}]}]
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
echo "  hooki w $SETTINGS (kopia zapasowa obok)"

if [ -d "$OPENCODE" ] || command -v opencode >/dev/null; then
  echo "OpenCode:"
  mkdir -p "$OPENCODE/commands" "$OPENCODE/plugins"
  for c in $COMMANDS; do
    dest="$OPENCODE/commands/$c.md"
    if [ -e "$dest" ] && ! grep -q "$MARKER" "$dest"; then
      echo "  Pomijam $dest — istnieje i nie pochodzi z aiw."
      continue
    fi
    # Frontmatter Claude Code -> OpenCode: context: fork -> subtask: true; pola specyficzne dla Claude usunięte.
    # Ścieżki ~/.claude rozwinięte, bo OpenCode nie gwarantuje rozwijania tyldy w !`...`.
    awk -v marker="$MARKER" -v home="$HOME" '
      NR == 1 && /^---$/ { fm = 1; print; print marker; next }
      fm && /^---$/ { fm = 0; print; next }
      fm && /^(name|argument-hint|disable-model-invocation|allowed-tools|agent):/ { next }
      fm && /^context: *fork/ { print "subtask: true"; next }
      { gsub(/~\/\.claude\//, home "/.claude/"); print }
    ' "$REPO/commands/$c.md" > "$dest"
    echo "  $dest"
  done
  link "$REPO/opencode/aiw.js" "$OPENCODE/plugins/aiw.js" || true
fi

echo
echo "Gotowe. Uruchom ponownie Claude Code / OpenCode w projekcie iOS i wpisz: /spec <opis zadania>"
echo "Po zmianach w commands/*.md uruchom install.sh ponownie (regeneruje wersje dla OpenCode)."
