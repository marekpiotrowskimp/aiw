#!/bin/bash
# Stop: podczas /implement agent nie może zakończyć pracy, dopóki:
#   1) zatwierdzone testy są nietknięte (zmienione zostają przywrócone),
#   2) build i wszystkie testy przechodzą.
# Wyjście awaryjne: agent zgłasza blokadę (aiw blocker), wtedy może się zatrzymać i zapytać.
AIW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/aiw"
cat >/dev/null

"$AIW" is-active || exit 0
STATE="$("$AIW" state-dir)"

say() { jq -n --arg m "$1" '{systemMessage: $m}'; exit 0; }
block() { jq -n --arg r "$1" '{decision: "block", reason: $r}'; exit 0; }

if [ -f "$STATE/blocker" ]; then
  echo "BLOCKED" > "$STATE/status"
  say "⛔ aiw: agent zgłosił blokadę: $(cat "$STATE/blocker")"
fi

if tampered="$("$AIW" check-tests --restore)"; then :; else
  block "Zmieniono zablokowane pliki testowe — zostały przywrócone do wersji zatwierdzonej przez użytkownika:
$tampered
Nie modyfikuj testów. Popraw kod produkcyjny. Jeśli test jest błędny, użyj: ~/.claude/ai-workflow/bin/aiw blocker \"<dlaczego>\"."
fi

fp="$("$AIW" fingerprint)"
if [ -f "$STATE/fingerprint" ] && [ "$(cat "$STATE/fingerprint")" = "$fp" ]; then
  exit 0   # od ostatniego zielonego przebiegu nic się nie zmieniło
fi

if "$AIW" test >/dev/null; then
  echo "$fp" > "$STATE/fingerprint"
  echo "GREEN $(date '+%Y-%m-%d %H:%M')" > "$STATE/status"
  rm -f "$STATE/stop_count"
  say "✅ aiw: build i wszystkie testy przechodzą."
fi

count=$(( $(cat "$STATE/stop_count" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$STATE/stop_count"
max="$("$AIW" max-blocks)"
if [ "$count" -ge "$max" ]; then
  echo "FAILED (po $count próbach)" > "$STATE/status"
  say "❌ aiw: testy nadal nie przechodzą po $count próbach — zadanie NIEUKOŃCZONE. Log: $STATE/last-test.log"
fi

block "Build lub testy nie przechodzą (próba $count/$max). Napraw kod produkcyjny, nie testy.
$("$AIW" test-summary)"
