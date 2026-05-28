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
- Neue Jobs hinzufuegen und vorhandene parsebare Jobs bearbeiten
- Script-Pfad manuell eingeben oder per Dateiauswahl setzen
- Zeitplan flexibel setzen:
  - Wochentag
  - bestimmte Stunde, jede Stunde oder alle N Stunden
  - bestimmte Minute, jede Minute oder alle N Minuten
- Jobs aktivieren/deaktivieren
- Cron-Zeile vor dem Speichern anzeigen
- Kommentare, Leerzeilen und nicht parsebare Crontab-Zeilen erhalten
- Als normale User-Crontab speichern

Beispiel:

```cron
0 2 * * * '/Users/mathis/bin/example.sh'
# 0 * * * * '/Users/mathis/bin/disabled.sh'
```

## Hinweis

Die App kann einfache Cron-Ausdruecke bearbeiten: `*`, konkrete Zahlen und `*/N` fuer Minute und Stunde. Komplexere Cron-Syntax bleibt als nicht parsebare Zeile erhalten.
