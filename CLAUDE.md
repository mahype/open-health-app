# OpenHealth – Claude Code Anweisungen

## Build-Pflicht nach Feature-Implementierungen

Nach jedem Vorgang, bei dem neue Features hinzugefügt oder bestehende Funktionen geändert wurden, **muss** am Ende ein Build durchgeführt werden.

### Ablauf

1. Feature implementieren
2. Build ausführen:
   ```bash
   xcodebuild -project OpenHealth.xcodeproj -scheme OpenHealth -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -50
   ```
3. Falls der Build Fehler enthält: Fehler analysieren und beheben
4. Build erneut ausführen – Schritt 3 und 4 wiederholen, bis der Build **erfolgreich** abgeschlossen wird (Build Succeeded)

### Ziel

Kein Feature-Vorgang darf in einem fehlerhaften Build-Zustand enden. Kompilierungsfehler, fehlende Importe oder Typfehler müssen vor dem Abschluss der Aufgabe vollständig behoben werden.
