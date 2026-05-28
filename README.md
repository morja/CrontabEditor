# Crontab Editor

Minimaler macOS-SwiftUI-Editor fuer User-Cronjobs.

## Starten

```sh
swift run
```

Falls beim Start ueber SwiftPM kein Fenster sichtbar wird, baue und oeffne die App als echtes macOS-Bundle:

```sh
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/CrontabEditor.app
```

Das Script baut standardmaessig einen Release-Build und signiert die App ad-hoc:

```sh
codesign --verify --deep --strict .build/CrontabEditor.app
```

Ad-hoc-Signing ist fuer lokale Tests und direkte Weitergabe brauchbar. Fuer eine oeffentliche Verteilung ohne Gatekeeper-Warnung brauchst du zusaetzlich eine Apple Developer ID Signatur und Notarisierung.

## Aktueller Umfang

- Mehrere Cronjobs aus der User-Crontab lesen
- LaunchAgent-Jobs aus `~/Library/LaunchAgents/local.crontabeditor.*.plist` lesen
- LaunchDaemon-Jobs aus `/Library/LaunchDaemons/local.crontabeditor.*.plist` lesen
- Neue Jobs hinzufuegen und vorhandene parsebare Jobs bearbeiten
- Pro Job zwischen `Crontab`, `LaunchAgent` und `LaunchDaemon` waehlen
- Pro Job einen Namen vergeben; LaunchD nutzt daraus eine stabile ID wie `local.crontabeditor.mein-job`
- Script-Pfad manuell eingeben oder per Dateiauswahl setzen
- Eigenes macOS-App-Icon im Bundle
- Zeitplan flexibel setzen:
  - mehrere Wochentage inklusive Werktage/Wochenende
  - bestimmte Stunde, jede Stunde oder alle N Stunden
  - bestimmte Minute, jede Minute oder alle N Minuten
  - mehrere feste Uhrzeiten pro Tag
- `RunAtLoad`: beim Laden sofort starten
- `Run now`: ausgewählten Job sofort starten
- Advanced-Bereich mit optionalem Logging und beschrifteten stdout/stderr Logpfaden
- Jobs aktivieren/deaktivieren
- Cron-Zeile vor dem Speichern anzeigen
- Kommentare, Leerzeilen und nicht parsebare Crontab-Zeilen erhalten
- Als normale User-Crontab speichern
- LaunchAgent-Plists schreiben und per `launchctl bootstrap/bootout` laden
- LaunchDaemon-Plists mit Admin-Prompt installieren, `root:wheel`/`644` setzen und per `launchctl bootstrap system` laden

Beispiel:

```cron
0 2 * * * '/Users/mathis/bin/example.sh'
# 0 * * * * '/Users/mathis/bin/disabled.sh'
```

## Hinweis

Die App kann einfache Cron-Ausdruecke bearbeiten: `*`, konkrete Zahlen und `*/N` fuer Minute und Stunde. Komplexere Cron-Syntax bleibt als nicht parsebare Zeile erhalten.

LaunchAgent ist User-bezogen. LaunchDaemon ist systemweit und laeuft auch ohne Login, braucht aber Admin-Rechte. Die aktuelle Implementierung nutzt dafuer den macOS-Admin-Prompt via AppleScript. Fuer eine verteilbare Produktversion waere ein signiertes privileged helper tool sauberer.

## Gut umsetzbare weitere Schedules

- Bei Login starten (`RunAtLoad`)
- Alle N Sekunden/Minuten/Stunden (`StartInterval`)
- Mehrere feste Uhrzeiten pro Tag
- Mehrere Wochentage
- Bestimmter Tag im Monat
- Bestimmter Monat oder Datumskombination
- Nach Netzwerk-/Pfad-Verfuegbarkeit starten (`WatchPaths`, `QueueDirectories`)
- Nur einmalig zur naechsten geplanten Zeit anlegen und danach deaktivieren
