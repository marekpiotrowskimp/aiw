# Konfiguracja aiw dla jednego projektu.
# Plik lokalny (~/.claude/ai-workflow-data/...), nigdy nie trafia do repozytorium zespołu.

# Build + testy. Musi zwrócić kod != 0, gdy cokolwiek nie przechodzi.
# Dostępne schematy:   xcodebuild -list -workspace App.xcworkspace
# Dostępne symulatory: xcrun simctl list devices available
AIW_TEST_CMD="xcodebuild test -workspace App.xcworkspace -scheme App -destination 'platform=iOS Simulator,name=iPhone 16' -quiet"

# Pliki testowe — blokowane podczas /implement (globy względem korzenia repo, rozdzielone spacją).
AIW_TEST_GLOBS="*Tests/* *Tests.swift */__Snapshots__/*"

# Ścieżki wysokiego ryzyka — jeśli diff ich dotyka, raport każe Ci przeczytać kod.
AIW_HIGH_RISK_GLOBS="*Auth* *Login* *Payment* *Purchase* *Keychain* *Migration* *.xcdatamodeld/* *.entitlements *Info.plist *.pbxproj"

# Opcjonalny linter uruchamiany po każdej edycji pliku .swift (ścieżka pliku dopisywana na końcu).
# Np.: AIW_LINT_CMD="swiftlint lint --quiet --path"
AIW_LINT_CMD=""

# Ile razy Stop hook może odesłać agenta do poprawek, zanim zadanie zostanie oznaczone jako FAILED.
AIW_MAX_STOP_BLOCKS=6
