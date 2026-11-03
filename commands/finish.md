---
name: finish
description: Etap 4 osobistego workflow aiw — zamyka zadanie, odblokowuje testy i pokazuje raport końcowy. Uruchamiany ręcznie.
disable-model-invocation: true
allowed-tools: Bash(~/.claude/ai-workflow/bin/aiw finish)
---

# /finish — zamknięcie zadania

Raport końcowy (testy zostały odblokowane przez tę komendę):
!`~/.claude/ai-workflow/bin/aiw finish`

Przedstaw użytkownikowi raport po polsku, zwięźle:
- wynik testów,
- czy są pliki wysokiego ryzyka, które musi przeczytać (wymień je),
- czy agent zgłosił blokadę albo dodał testy bez zatwierdzenia.

Następnie zaproponuj podział zmian na małe, logiczne commity, np. osobno testy charakteryzacyjne, testy nowych kryteriów i implementację. Pokaż proponowane komunikaty commitów. **Nie commituj i nie pushuj** bez wyraźnej prośby użytkownika.
