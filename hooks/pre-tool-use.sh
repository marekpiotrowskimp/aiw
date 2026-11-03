#!/bin/bash
# PreToolUse: podczas /implement blokuje zmiany zatwierdzonych testów i stanu workflow.
# Zawsze: blokada (lock) i odblokowanie (finish) to decyzje użytkownika, wykonywane tylko przez komendy.
# Poza aktywną implementacją nic więcej nie robi.
AIW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/aiw"
input="$(cat)"

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

if [ "$(jq -r '.tool_name' <<<"$input")" = "Bash" ]; then
  case "$(jq -r '.tool_input.command // empty' <<<"$input")" in
    *"aiw lock"*|*"aiw finish"*)
      deny "Blokadę i odblokowanie testów wykonuje wyłącznie użytkownik komendami /implement i /finish." ;;
  esac
fi

"$AIW" is-active || exit 0

TESTS_LOCKED="Testy są zablokowane — zatwierdził je użytkownik i stanowią kontrakt. Zmień kod produkcyjny, nie testy. Jeśli uważasz, że test jest błędny lub sprzeczny ze specyfikacją, uruchom: ~/.claude/ai-workflow/bin/aiw blocker \"<dlaczego>\" i zatrzymaj się."

data_dir="$("$AIW" data-dir)"
tool="$(jq -r '.tool_name' <<<"$input")"

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
    [ -z "$path" ] && exit 0
    case "$path" in "$data_dir"/*) deny "Stan workflow aiw jest tylko do odczytu podczas implementacji." ;; esac
    "$AIW" match-test "$path" && deny "$TESTS_LOCKED"
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
    case "$cmd" in
      *ai-workflow-data*|*"aiw finish"*|*"aiw lock"*|*"aiw begin"*|*"aiw init"*)
        deny "Tę operację wykonuje wyłącznie użytkownik (/finish). Dozwolone: aiw status, aiw blocker, aiw test." ;;
    esac
    # Heurystyka: operacja zapisu + ścieżka testowa. Ostateczną ochroną jest kontrola sum w Stop hooku.
    stripped="$(sed -E 's/[0-9]?>&[0-9]//g; s#[0-9]?>+ */dev/null##g' <<<"$cmd")"
    if grep -qE '(^|[;&|( ]) *(rm|mv|cp|tee|truncate|ditto|patch|sed +-i|perl +-[a-z]*i|git +(checkout|restore|rm|mv|apply|stash|reset|clean))( |$)|>' <<<"$stripped"; then
      for word in $(tr -d "\"'" <<<"$stripped"); do
        word="${word#*:}"   # np. -only-testing:AppTests/Foo
        "$AIW" match-test "$word" && deny "$TESTS_LOCKED (polecenie modyfikuje: $word)"
      done
    fi
    ;;
esac
exit 0
