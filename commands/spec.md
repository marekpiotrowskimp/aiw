---
name: spec
description: Etap 1 osobistego workflow aiw — specyfikacja i testy (kontrakt) przed jakąkolwiek implementacją. Uruchamiany ręcznie.
argument-hint: <opis funkcjonalności lub zmiany>
disable-model-invocation: true
allowed-tools: Bash(~/.claude/ai-workflow/bin/aiw status)
---

# /spec — kontrakt przed kodem

Zadanie od użytkownika: **$ARGUMENTS**

Stan workflow:
!`~/.claude/ai-workflow/bin/aiw status`

W tym etapie **nie implementujesz funkcjonalności**. Tworzysz kontrakt: specyfikację i testy. Użytkownik ma mało czasu, więc przeczyta tylko specyfikację i podsumowanie testów, a nie kod. Testy muszą więc same w sobie jednoznacznie opisywać oczekiwane zachowanie.

Zasady pracy w repozytorium zespołu:
- Nie modyfikuj `CLAUDE.md`, `.claude/`, `.gitignore`, ustawień projektu ani zależności (SPM/CocoaPods) bez wyraźnej zgody.
- Pisz testy w konwencji, której projekt już używa (XCTest lub Swift Testing, istniejące helpery, mocki, nazewnictwo). Jeśli projekt ma już `swift-snapshot-testing`, użyj go do widoków SwiftUI/UIKit.
- Narzędzie `aiw` zawsze wywołuj pełną ścieżką: `~/.claude/ai-workflow/bin/aiw`.

## Kroki

1. **Konfiguracja.** Jeśli status pokazuje `config: BRAK`:
   - uruchom `aiw init`,
   - ustal workspace/projekt i scheme z testami (`xcodebuild -list`) oraz dostępny symulator (`xcrun simctl list devices available`),
   - uzupełnij `AIW_TEST_CMD` w pliku configu (ścieżka w `aiw paths`),
   - dopasuj `AIW_TEST_GLOBS` do rzeczywistego układu katalogów testowych i pokaż użytkownikowi wynik.

2. **Rozpoczęcie zadania.** Uruchom `aiw begin <krótka-nazwa-kebab-case>`. Komenda zwraca ścieżkę pliku specyfikacji z szablonem.

3. **Rozpoznanie.** Przeczytaj kod, którego dotyczy zmiana. Znajdź wszystkie miejsca użycia typów i funkcji, które zmienisz. Sprawdź, jakie testy już je pokrywają.

4. **Specyfikacja.** Wypełnij plik specyfikacji:
   - kryteria akceptacji w formie Given/When/Then, które da się sprawdzić testem,
   - przypadki brzegowe (sieć, pusty stan, błędy, MainActor/wątki, Dynamic Type, dark mode, dostępność — tylko te, które dotyczą zadania),
   - sekcję **„Poza zakresem — NIE WOLNO zmieniać”**,
   - poziom ryzyka.
   
   Niejasności zapisz w „Otwarte pytania”. Nie zgaduj.

5. **Testy charakteryzacyjne.** Dla każdego istniejącego zachowania, które zmiana może naruszyć, a które nie jest pokryte testem, napisz test opisujący **obecne** zachowanie. Te testy muszą przechodzić **teraz**.

6. **Testy nowych kryteriów.** Każde kryterium akceptacji i każdy istotny przypadek brzegowy potrzebuje co najmniej jednego testu. Asercje mają być konkretne: dokładne wartości, a nie tylko `XCTAssertNotNil` czy „nie crashuje”. Jeśli test nie skompiluje się bez nowego API, dodaj w kodzie produkcyjnym **minimalny szkielet**: sygnatury zwracające wartość domyślną, bez logiki i bez `fatalError`. Dzięki temu testy kompilują się i są czerwone.

7. **Weryfikacja kontraktu.** Uruchom testy (`aiw test`, a przy błędach `aiw test-summary`; do szybkich iteracji możesz użyć `xcodebuild ... -only-testing:`). Oczekiwany stan:
   - testy charakteryzacyjne i istniejące: **zielone**,
   - nowe testy kryteriów: **czerwone z właściwego powodu** (niespełniona asercja, a nie błąd kompilacji).
   
   Uzupełnij kolumnę „Stan przed implementacją” w planie testów.

8. **Podsumowanie dla użytkownika.** Zakończ krótko, po polsku, w tej formie:
   - ścieżka do specyfikacji,
   - tabela: kryterium → nazwa testu → w jednym zdaniu, co dokładnie sprawdza asercja,
   - lista testów charakteryzacyjnych,
   - otwarte pytania, jeśli są,
   - na końcu: „Jeśli kontrakt jest OK, uruchom **/implement**. Od tego momentu testy będą zablokowane.”

Nie przechodź do implementacji, nawet jeśli wydaje się prosta.
