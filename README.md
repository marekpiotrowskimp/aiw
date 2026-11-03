# aiw — „kontrakt przed kodem” dla agentów AI (iOS / Swift)

Osobisty workflow dla **Claude Code** i **OpenCode**, który znacząco ogranicza dwa najczęstsze problemy pracy z agentem AI:

1. **Regresje.** Agent przy okazji psuje działające funkcjonalności.
2. **Błędy w nowym kodzie.** Agent dostarcza funkcję, która „wygląda dobrze”, ale nie działa w przypadkach brzegowych. Czasem też pokazuje zielone testy, bo po cichu zmienił testy zamiast kodu.

Workflow jest przeznaczony dla osób, które **nie zawsze mają czas przeczytać cały kod wygenerowany przez agenta**, a mimo to muszą mieć pewność, że działa.

---

## Po co to jest

Typowa praca z agentem wygląda tak: prosisz o funkcję, agent pisze kod, mówi „gotowe, testy przechodzą”, a Ty albo czytasz każdą linię (i tracisz zysk z AI), albo wierzysz na słowo (i ryzykujesz błędy na produkcji).

Doświadczenia innych zespołów i badania (patrz [Źródła](#źródła)) prowadzą do kilku wniosków:

- **Agent musi mieć deterministyczny sposób sprawdzenia swojej pracy.** To najskuteczniejsza pojedyncza praktyka według Anthropic.
- **Instrukcje w promptach i `CLAUDE.md` są prośbami, a nie gwarancjami.** Agent czasem je pomija. Reguły, które muszą obowiązywać, trzeba egzekwować kodem (hookami).
- **Agenci potrafią oszukiwać testy**: zmieniają asercje, dodają `skip`, wpisują wyniki na sztywno. Najtańsza ochrona to testy tylko do odczytu oraz danie agentowi jawnej drogi „nie da się, zgłaszam problem”.
- **Ogólne „pisz testy / stosuj TDD” w prompcie może zwiększyć liczbę regresji.** Pomaga konkretny kontekst: które testy chronią daną zmianę.

## Główna idea

> **Ty sprawdzasz „co” (kontrakt). Maszyna sprawdza „jak” (kod).**

Przeczytanie 500 linii kodu zajmuje ok. 30 minut. Przeczytanie 10 kryteriów akceptacji i nazw testów zajmuje 3–5 minut. To drugie da się robić zawsze, nawet pod presją czasu. Resztę egzekwują automaty, których agent nie może obejść.

```
 /spec ──────────────► Ty: 3–5 min ──► /implement ──────────────► /audit ─────────────► /finish
 agent pisze:          czytasz spec    testy ZABLOKOWANE           niezależny            raport,
 • specyfikację        i tabelę        agent nie skończy, dopóki   recenzent w           odblokowanie,
 • testy obecnego      „kryterium →    build + wszystkie testy     osobnym kontekście:   propozycja
   zachowania (zielone) test → asercja”  nie przejdą               „czy musisz czytać    commitów
 • testy nowych                                                    diff? TAK/NIE”
   kryteriów (czerwone)
```

## Korzyści

| Korzyść | Jak to osiągamy |
|---|---|
| **Mniej regresji** | Zanim agent zmieni istniejący kod, zapisuje jego obecne zachowanie w testach charakteryzacyjnych. Na końcu musi przejść cały zestaw testów. |
| **Testy nie kłamią** | Zatwierdzone testy są zablokowane. Próba edycji jest odrzucana, a zmiany wprowadzone obejściem są automatycznie cofane. |
| **Agent nie ogłosi sukcesu na wyrost** | Testy uruchamia hook, a nie agent. Agent nie zakończy pracy, dopóki nie są zielone. |
| **Uczciwość zamiast obejść** | Agent ma jawne wyjście awaryjne (`aiw blocker`): zgłasza problem zamiast go maskować. |
| **Wiesz, kiedy musisz czytać kod** | Audyt i lista ścieżek wysokiego ryzyka (auth, płatności, migracje, `.pbxproj`) mówią wprost, czy ten diff wymaga Twojej uwagi. |
| **Mniej czasu na review** | Czytasz kontrakt (minuty), a nie implementację (dziesiątki minut). |
| **Zero wpływu na zespół** | Nic nie trafia do repozytorium: żaden `CLAUDE.md`, `.claude/` ani `.gitignore`. Każdy decyduje sam, czy tak pracuje. |
| **Niezależność od dostawcy AI** | Te same komendy i reguły działają w Claude Code i OpenCode, z dowolnym modelem. Stan zadania jest wspólny. |

---

## Wymagania

- macOS z Xcode (`xcodebuild`) i `git`
- `jq` (wbudowany w nowsze macOS lub `brew install jq`)
- Claude Code i/lub OpenCode
- Opcjonalnie: SwiftLint (lint po każdej edycji), [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing), jeśli projekt już go używa (testy widoków)

## Instalacja

```bash
git clone <url-tego-repo> ~/Projects/aiw
cd ~/Projects/aiw
./install.sh
```

Następnie zrestartuj Claude Code / OpenCode. Deinstalacja: `./uninstall.sh`. Usuwa wszystko oprócz Twoich danych projektów.

Instalator działa wyłącznie w Twoim katalogu domowym:

| Co | Gdzie |
|---|---|
| Narzędzie i hooki | `~/.claude/ai-workflow` → symlink do tego repo |
| Komendy Claude Code | `~/.claude/commands/{spec,implement,audit,finish}.md` (symlinki) |
| Hooki Claude Code | dopisane do `~/.claude/settings.json` (z kopią zapasową) |
| Komendy OpenCode | `~/.config/opencode/commands/*.md` (generowane) |
| Plugin OpenCode | `~/.config/opencode/plugins/aiw.js` (symlink) |
| Config, specyfikacje, stan | `~/.claude/ai-workflow-data/projects/<projekt>/` |

Hooki są globalne, ale **nieaktywne** poza etapem `/implement`. W pozostałych sytuacjach nie robią nic i nie spowalniają pracy.

---

## Jak pracować — krok po kroku

### 1. `/spec <opis zadania>` — kontrakt

```
/spec dodaj logowanie Face ID z fallbackiem na PIN po 3 nieudanych próbach
```

Agent:
- przy pierwszym użyciu w projekcie wykrywa scheme i symulator i tworzy lokalny config,
- czyta dotknięty kod i jego miejsca użycia,
- pisze specyfikację: kryteria akceptacji (Given/When/Then), przypadki brzegowe, sekcję **„Poza zakresem — NIE WOLNO zmieniać”**, poziom ryzyka,
- pisze **testy charakteryzacyjne** istniejącego zachowania, które muszą być **zielone**,
- pisze **testy nowych kryteriów**, które muszą być **czerwone z właściwego powodu**,
- **nie implementuje** funkcji.

**Twoja rola (jedyny krok, którego nie wolno pominąć):** przeczytaj tabelę „kryterium → test → co sprawdza asercja” i zadaj sobie jedno pytanie: *„Jeśli te testy przejdą, czy funkcja działa tak, jak chcę?”*. Jeśli nie, poproś o poprawki jeszcze w tej fazie.

### 2. `/implement` — implementacja względem zablokowanego kontraktu

Uruchomienie komendy oznacza Twoją akceptację kontraktu. Od tej chwili:
- pliki testowe są **zablokowane**,
- agent **nie może zakończyć pracy**, dopóki build i wszystkie testy nie przejdą,
- jeśli test okaże się błędny, agent zgłasza blokadę i zatrzymuje się, zamiast obchodzić problem,
- po N nieudanych próbach (domyślnie 6) zadanie jest oznaczane jako **FAILED**, a agent przestaje się kręcić w kółko.

Ponowne `/implement` (np. po wyjaśnieniu blokady) wznawia pracę z nową pulą prób.

### 3. `/audit` — niezależny recenzent

Uruchamia się w osobnym kontekście, bez historii rozmowy autora. Sprawdza:
- zgodność ze specyfikacją,
- zmiany poza zakresem,
- regresje u innych wywołujących,
- obejścia,
- pułapki iOS: `@MainActor`, cykle referencji, `Task`, cykl życia widoków.

Zwraca:

```
WERDYKT: OK | DO POPRAWY | STOP
CZY MUSISZ CZYTAĆ DIFF: NIE | TAK — <które pliki i dlaczego>
```

### 4. `/finish` — zamknięcie

Odblokowuje testy, pokazuje raport (wynik testów, pliki wysokiego ryzyka, ewentualne blokady) i proponuje podział na małe commity. **Niczego nie commituje bez Twojej prośby.**

### Kiedy mimo wszystko czytać kod

| Poziom ryzyka | Przykłady | Twoja kontrola |
|---|---|---|
| Niski | UI, teksty, izolowane nowe moduły | spec + tabela testów |
| Średni | logika biznesowa, zmiany istniejących funkcji | spec + tabela testów + werdykt `/audit` |
| Wysoki | autoryzacja, płatności, Keychain, migracje danych, `.pbxproj`, entitlements | **zawsze czytasz diff wskazanych plików** |

O tym, co jest „wysokim ryzykiem”, decyduje config (`AIW_HIGH_RISK_GLOBS`), a nie agent.

---

## Konfiguracja projektu

Plik `~/.claude/ai-workflow-data/projects/<projekt>/config.sh` (tworzony przy pierwszym `/spec`):

| Zmienna | Znaczenie |
|---|---|
| `AIW_TEST_CMD` | build + testy, np. `xcodebuild test -workspace App.xcworkspace -scheme App -destination 'platform=iOS Simulator,name=iPhone 16' -quiet` |
| `AIW_TEST_GLOBS` | które pliki są testami (blokowane w `/implement`) |
| `AIW_HIGH_RISK_GLOBS` | ścieżki wymagające Twojej lektury diffu |
| `AIW_LINT_CMD` | opcjonalny linter po każdej edycji `.swift` |
| `AIW_MAX_STOP_BLOCKS` | ile razy agent może zostać odesłany do poprawek |

Przy dużym projekcie zawęź `AIW_TEST_CMD` (osobny test plan, `-only-testing:`), bo jest uruchamiane przy każdym zakończeniu tury w `/implement`.

Pomocnicze polecenia (w sesji poprzedź je `!`):

```bash
~/.claude/ai-workflow/bin/aiw status    # faza, wynik testów, blokady
~/.claude/ai-workflow/bin/aiw report    # raport zmian od początku zadania
```

---

## Jak to działa pod spodem

| Mechanizm | Claude Code | OpenCode |
|---|---|---|
| Komendy | `~/.claude/commands/*.md` | generowane z tych samych plików (`context: fork` → `subtask: true`) |
| Blokada edycji testów | hook `PreToolUse` → deny | plugin `tool.execute.before` → wyjątek (także `apply_patch`) |
| Wykrycie i cofnięcie zmian w testach | sumy kontrolne + snapshot przy zakończeniu tury | to samo |
| „Nie skończysz bez zielonych testów” | hook `Stop` blokuje zakończenie | po `session.idle` plugin uruchamia testy i przy błędzie odsyła agentowi prompt |
| Linter po edycji | hook `PostToolUse` | dopisanie wyniku do outputu narzędzia |

Wszystkie reguły są zapisane w `hooks/*.sh`. Plugin OpenCode tylko tłumaczy zdarzenia i wywołuje te same skrypty, więc obie platformy zachowują się tak samo.

```
bin/aiw            narzędzie: init, begin, lock, test, report, finish, blocker
hooks/             reguły (wspólne dla obu narzędzi)
commands/          /spec /implement /audit /finish (jedno źródło)
opencode/aiw.js    adapter OpenCode
templates/         config.sh i szablon specyfikacji
```

## Rozwiązywanie problemów

**`/implement` nie zablokował testów, a agent prosi o ręczne `aiw lock`.** Każda komenda ma w `allowed-tools` zezwolenie na swoje polecenie `aiw`. Bez niego Claude Code w trybie auto nie wykonuje polecenia `` !`…` `` sam, tylko prosi o to agenta. Hook słusznie blokuje agentowi `aiw lock`, więc wtedy nic się nie dzieje. Sprawdź, czy `~/.claude/commands/implement.md` wskazuje na aktualną wersję z repo i czy żadna reguła `deny`/`ask` w Twoich ustawieniach uprawnień nie obejmuje `aiw`. Doraźnie: `! ~/.claude/ai-workflow/bin/aiw lock`, potem ponownie `/implement`.

**Komendy `/spec`, `/implement`… zniknęły z Claude Code / OpenCode.** Instalacja to symlinki do katalogu repo. Po przeniesieniu lub przemianowaniu repo wskazują w próżnię. Uruchom `./install.sh` z nowej lokalizacji, a symlinki zostaną przepięte.

**Po przemianowaniu projektu aiw „nie pamięta” specyfikacji.** Dane projektu są przypisane do jego ścieżki (`~/.claude/ai-workflow-data/projects/<ścieżka-z-myślnikami>/`). Przemianuj ten katalog zgodnie z nową ścieżką projektu.

## Ograniczenia — uczciwie

- **Zły kontrakt = zielone, ale błędne.** Jeśli specyfikacja i testy są błędne, wszystko przejdzie. Dlatego krok 1 jest obowiązkowy.
- **Blokada poleceń bash to heurystyka.** Ostatnią linią obrony jest kontrola sum testów przy każdym zakończeniu tury. Zmienione testy są przywracane.
- **To nie zastępuje CI ani code review zespołu.** To dodatkowa warstwa przed wypchnięciem zmian.
- **OpenCode nie ma odpowiednika Stop hooka.** Agent najpierw kończy turę, a dopiero potem dostaje prompt z błędami. Adapter testowano na OpenCode 2.0.20; nazwy narzędzi mogą się zmienić w nowszych wersjach.
- **Pełne `xcodebuild test` jest wolne.** Zawęź zakres testów w configu.

---

## Źródła

Workflow powstał na podstawie poniższych materiałów. Część to badania naukowe, część dokumentacja narzędzi, a część to doświadczenia praktyków. Te ostatnie warto traktować jako obserwacje, a nie twarde dowody.

### Badania

- [TDAD: Test-Driven Agentic Development (arXiv, 2026)](https://arxiv.org/abs/2603.17973) — agent bez wsparcia psuł średnio ~6,5 testu na poprawkę. Samo „stosuj TDD” w prompcie **zwiększyło** liczbę regresji. Wskazanie agentowi testów powiązanych ze zmienianym kodem zmniejszyło je o ok. 70%. Podstawa testów charakteryzacyjnych i pełnego zestawu testów przy zakończeniu tury.
- [EvilGenie: A Reward Hacking Benchmark (arXiv)](https://arxiv.org/abs/2511.21654) — dokumentuje, jak agenci „oszukują” testy (edycja plików testowych, wyniki na sztywno) i jak to wykrywać. Podstawa blokady i sum kontrolnych testów.
- [The Verification Horizon: No Silver Bullet for Coding Agent Rewards (arXiv)](https://arxiv.org/pdf/2606.26300) — ograniczenia automatycznej weryfikacji pracy agentów. Uzasadnienie, dlaczego kontrakt zatwierdza człowiek.
- [AIDev: Studying AI Coding Agents on GitHub (arXiv)](https://arxiv.org/html/2602.09185v1) — zbiór ponad 33 tys. pull requestów tworzonych przez agentów z ok. 2,8 tys. repozytoriów.
- [What 33,000 Agentic Pull Requests Reveal](https://codex.danielvaughan.com/2026/04/18/empirical-research-agentic-pull-requests-codex-cli/) — praktyczne wnioski z tych danych: małe, skupione zmiany zweryfikowane przez CI są przyjmowane częściej. Podstawa propozycji małych commitów w `/finish`.

### Dokumentacja narzędzi

- [Claude Code — Best Practices](https://code.claude.com/docs/en/best-practices.md) — najważniejsza praktyka według Anthropic: daj agentowi sposób na sprawdzenie własnej pracy (testy, build, zrzut ekranu).
- [Claude Code — Power user tips](https://support.claude.com/en/articles/14554000-claude-code-power-user-tips) — weryfikacja jako praktyka o największym wpływie na jakość wyniku.
- [Claude Code — Hooks](https://code.claude.com/docs/en/hooks.md) — `PreToolUse`, `PostToolUse` i `Stop` oraz sposób blokowania akcji. Podstawa techniczna egzekwowania reguł.
- [Claude Code — Skills / komendy](https://code.claude.com/docs/en/skills.md) — komendy `/…`, `$ARGUMENTS`, wstrzykiwanie wyniku poleceń `` !`…` ``, `context: fork` dla audytu w osobnym kontekście.
- [Claude Code — Memory (CLAUDE.md)](https://code.claude.com/docs/en/memory.md) — CLAUDE.md to kontekst, a nie egzekwowana konfiguracja. Do blokowania akcji służą hooki. Opisuje też, jak trzymać ustawienia osobiste poza repozytorium.
- [OpenCode — Commands](https://opencode.ai/docs/commands/) — format komend OpenCode (`$ARGUMENTS`, `` !`…` ``, `subtask`).
- [OpenCode — Plugins](https://opencode.ai/docs/plugins/) — zdarzenia `tool.execute.before/after` i `session.idle`, na których opiera się adapter.
- [OpenCode — SDK](https://opencode.ai/docs/sdk/) — `session.prompt` i `tui.showToast`, używane do odsyłania agenta do poprawek.
- [OpenCode — Skills](https://opencode.ai/docs/skills/) — wyjaśnia, dlaczego workflow używa komend, a nie skilli: w OpenCode skille wywołuje model, a nie użytkownik.
- [Cursor — Reviewing and testing](https://cursor.com/learn/reviewing-testing) — małe, semantyczne commity. Kod agenta podlega tym samym standardom co kod ludzki. Typowe ryzyka: brakujące przypadki brzegowe i duplikacja logiki.

### Doświadczenia praktyków

- [Why "Always Run Tests" in AGENTS.md Makes Things Worse](https://codex.danielvaughan.com/2026/06/05/why-always-run-tests-agents-md-makes-things-worse/) — dlaczego ogólna instrukcja „uruchamiaj testy” w pliku agenta nie działa.
- [The 4 hooks every Claude Code project needs](https://pub.towardsai.net/the-4-hooks-every-claude-code-project-needs-665f8d610f8b) — instrukcje w CLAUDE.md są probabilistyczne, a hooki deterministyczne.
- [Claude Code deep dive: hooked](https://medium.com/@the.gigi/claude-code-deep-dive-hooked-8492c9b5c9fb) — agent pomijał testy mimo reguł w CLAUDE.md, więc egzekwowanie przeniesiono do hooków.
- [Claude Code hooks — practical guide (wmedia)](https://wmedia.es/en/writing/claude-code-hooks-practical-guide) — Stop hook uruchamiający testy i ochrona przed nieskończoną pętlą. Podstawa limitu prób.
- [Claude Code Hooks Examples (morphllm)](https://www.morphllm.com/claude-code-hooks-examples) — hooki muszą być szybkie, uruchamiaj powiązane testy zamiast całego zestawu po każdym zapisie. Podstawa cache'owania wyniku testów.
- [Claude Code TDD workflow (stacknotice)](https://stacknotice.com/blog/claude-code-tdd-workflow-2026) — red-green-refactor połączony z hookami.
- [Claude Code Best Practices: 3 Lessons from 400,000 Sessions (Analytics Vidhya)](https://www.analyticsvidhya.com/?p=256782) — „drabina weryfikacji”: od sprawdzenia w prompcie po Stop hook blokujący zakończenie.
- [Reward hacking — guardrails for AI agents (noqta)](https://noqta.tn/en/blog/reward-hacking-ai-agents-specification-gaming-guardrails-2026) — testy tylko do odczytu oraz możliwość zgłoszenia „zadanie niewykonalne”, która mocno ogranicza oszukiwanie. Podstawa `aiw blocker`.
- [Working method for AI coding agents (SpotDev)](https://www.spotdev.co.uk/blog/working-method-for-ai-coding-agents) — testy commitowane przed implementacją oraz ostrzeżenie, gdy test zmienia się w tym samym commicie co kod.
- [Should You Still Review Your AI Agent's Code?](https://agentsroom.dev/blog/should-you-review-ai-agent-code) — dokładność review dobierana do ryzyka zmiany. Podstawa poziomów ryzyka.

### Spec-driven development

- [GitHub Spec Kit](https://github.com/github/spec-kit) — wzorcowa implementacja podejścia: specyfikacja → plan → zadania → implementacja.
- [Spec-Driven Development in 2026: The Complete Guide](https://codemyspec.com/blog/spec-driven-development) — przegląd narzędzi i etapów SDD.
- [A Practical Guide to Spec-Driven Development with AI (Design News)](https://www.designnews.com/embedded-systems/a-practical-guide-to-spec-driven-development-with-ai) — rola inżyniera przesuwa się ze sterowania generowaniem kodu na weryfikację względem wymagań.
- [Spec-Driven Development: The Future of AI Coding or Waterfall 2.0?](https://alexcloudstar.com/blog/spec-driven-development-2026/) — krytyczne spojrzenie na narzut SDD. Dlatego tutaj specyfikacja jest krótka i obowiązkowa tylko w zakresie kryteriów i testów.

### Klasyka inżynierii

- [Characterization test (Wikipedia)](https://en.wikipedia.org/wiki/Characterization_test) — technika Michaela Feathersa (*Working Effectively with Legacy Code*): przed zmianą zapisz w testach obecne zachowanie kodu. Podstawa ochrony przed regresjami w `/spec`.
