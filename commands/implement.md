---
name: implement
description: Etap 2 osobistego workflow aiw — blokuje zatwierdzone testy i implementuje kod, aż build i wszystkie testy przejdą. Uruchamiany ręcznie po /spec.
argument-hint: [dodatkowe uwagi]
disable-model-invocation: true
allowed-tools: Bash(~/.claude/ai-workflow/bin/aiw lock)
---

# /implement — implementacja względem zablokowanego kontraktu

Blokada testów (wykonana przez użytkownika przez uruchomienie tej komendy):
!`~/.claude/ai-workflow/bin/aiw lock`

Jeśli powyżej jest linia zaczynająca się od `ERROR:`, **przerwij** i przekaż użytkownikowi ten komunikat.
Jeśli zamiast wyniku `aiw lock` widzisz prośbę o uruchomienie polecenia, **nie uruchamiaj go** i nie implementuj. Blokadę wykonuje tylko użytkownik. Poproś go o wpisanie `! ~/.claude/ai-workflow/bin/aiw lock` i ponowne `/implement`.

Uwagi użytkownika: $ARGUMENTS

Przeczytaj plik specyfikacji wskazany wyżej. Testy wymienione w planie testów to zatwierdzony kontrakt.

## Zasady (egzekwowane przez hooki)

- **Pliki testowe są zablokowane.** Edycja zostanie odrzucona, a zmiany wprowadzone obejściem zostaną cofnięte przy zakończeniu tury.
- **Nie zakończysz tury, dopóki build i wszystkie testy schematu nie przejdą.** Stop hook sam je uruchamia.
- **Wyjście awaryjne:** jeśli test jest błędny, sprzeczny ze specyfikacją albo zadania nie da się wykonać bez naruszenia sekcji „Poza zakresem”, uruchom
  `~/.claude/ai-workflow/bin/aiw blocker "<konkretny powód>"` i zatrzymaj się z wyjaśnieniem. Uczciwe zgłoszenie problemu jest **zawsze** lepsze niż obejście.

## Zakazane obejścia

- Warunki wykrywające środowisko testowe (`NSClassFromString("XCTest")`, flagi launch arguments, `#if DEBUG` zmieniające logikę) w celu przejścia testów.
- Wartości na sztywno dopasowane do danych z testów.
- Wyciszanie błędów: puste `catch`, `try?` gubiące błąd, który powinien być obsłużony, nowe `// swiftlint:disable`.
- `fatalError`, `!` (force unwrap) i `try!` w nowym kodzie produkcyjnym, chyba że projekt jawnie stosuje taki wzorzec.
- Zmiany poza zakresem specyfikacji: refaktoryzacje „przy okazji”, zmiany publicznego API, formatowanie niezwiązanych plików, zmiany w `.pbxproj` inne niż dodanie nowych plików.

## Sposób pracy

1. Małe kroki. Po każdym kroku uruchamiaj tylko powiązane testy (`-only-testing:`), żeby szybko dostać informację zwrotną.
2. Trzymaj się istniejących wzorców w module: architektury, nazewnictwa, wstrzykiwania zależności, obsługi błędów i `@MainActor`.
3. Na koniec uruchom pełne testy (`~/.claude/ai-workflow/bin/aiw test`). Przy błędach użyj `aiw test-summary`.
4. Podsumowanie dla użytkownika (krótko): co zmieniono (pliki i po jednym zdaniu na plik), czy cokolwiek wyszło poza specyfikację oraz wynik testów. Następny krok: **/audit**.
