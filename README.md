# PAGS Lernplaner

Lernplaner für Schülerinnen und Schüler der Pater-Alois-Grimm-Schule Külsheim: Aufgaben, IL-Stunden, Tages- und Wochenplanung, Prüfungsplaner, Kalender, Tour und FAQ.

Entwickelt von Thorsten von Plotho-Kettner.

**App:** https://ratpoison-de.github.io/pags-lernplaner/

## Kompakte Startseite

**https://ratpoison-de.github.io/pags-lernplaner/start/** – alle Apps nur mit Icon und Namen (Ordner `start/`).

## Übersichtsseite aller Apps

**https://ratpoison-de.github.io/pags-lernplaner/apps/**

Alle Apps (Lernplaner, Wochenstapel, Lernbegleiter, Fachschaft Deutsch, Korrekturtabelle, Lehrkraft-Seite, PAGS-App, Tag der Berufe, Wochenstapel für Android und als Datei) mit Anleitungen als PDF. Dateien im Ordner `apps/`.

## So funktioniert es

- Die App selbst liegt auf GitHub Pages (diese Dateien).
- Anmeldung und Speicherung laufen über [Supabase](https://supabase.com) (Server in der EU).
- Schülerinnen und Schüler legen ihr Konto selbst an: **Benutzername + Passwort**, ohne E-Mail-Adresse.
- Jede Person sieht nur ihre eigenen Daten (Row Level Security in der Datenbank).
- Alles wird automatisch gespeichert. Ohne Internet arbeitet die App mit einer lokalen Kopie weiter und lädt Änderungen hoch, sobald wieder eine Verbindung besteht.
- Solange `config.js` leer ist, läuft die App ohne Anmeldung und speichert nur auf dem Gerät.

## Einrichtung (einmalig, ca. 10 Minuten)

### 1. Supabase-Projekt anlegen
1. Auf https://supabase.com ein kostenloses Konto anlegen.
2. **New project** → Name z. B. `pags-lernplaner`, Region **Central EU (Frankfurt)**, sicheres Datenbank-Passwort vergeben.

### 2. Datenbank einrichten
1. Im Projekt links **SQL Editor** öffnen.
2. Den Inhalt von [`supabase/schema.sql`](supabase/schema.sql) einfügen und **Run** klicken.

### 3. Anmeldung einstellen
Unter **Authentication → Sign In / Providers → Email**:
- **Enable Email provider**: an
- **Confirm email**: **aus** (wichtig, die Schüler haben keine E-Mail-Adresse in der App)
- Unter **Authentication → Sign In / Providers**: **Allow new users to sign up**: an

Unter **Authentication → URL Configuration**:
- **Site URL**: `https://ratpoison-de.github.io/pags-lernplaner/`

### 4. App mit der Datenbank verbinden
Unter **Project Settings → API** die **Project URL** und den **anon public**-Schlüssel kopieren und in [`config.js`](config.js) eintragen. Committen, fertig. Nach etwa einer Minute ist die App mit Anmeldung online.

## Wochenstapel

**https://ratpoison-de.github.io/pags-lernplaner/wochenstapel/**

Minimalistische Wochen-To-do-App: die nächsten sieben Tage untereinander, Aufgaben abhaken, verschieben, wiederholen, per Ziehen umsortieren. Unerledigtes wandert automatisch nach „Heute“.

- Gleiche Konten wie der Lernplaner (Anmeldung im einen gilt auch im anderen).
- Daten pro Person in der Tabelle `wochenstapel` ([`supabase/wochenstapel.sql`](supabase/wochenstapel.sql)), nur für die eigene Person lesbar.
- Wird ein Konto über die Lehrkraft-Seite gelöscht, verschwinden auch die Wochenstapel-Daten.
- Über „Zum Startbildschirm hinzufügen“ wie eine App nutzbar.

## Lernbegleiter-App (für Lehrkräfte)

**https://ratpoison-de.github.io/pags-lernplaner/lernbegleiter/**

Wochenplanung für Lehrkräfte nach dem Prinzip des Wochenstapels. Jeder Tag hat vier Abschnitte: **Vorbereitung, Drucken, Einsammeln, Erledigen**. Aufgaben lassen sich mit Sternen als Favoriten markieren und über „Nur Favoriten“ filtern.

- Gleiche Konten wie Lernplaner und Wochenstapel, eigene Daten in der Tabelle `lernbegleiter` ([`supabase/lernbegleiter.sql`](supabase/lernbegleiter.sql)).
- Über „Zum Startbildschirm hinzufügen“ wie eine App nutzbar.

## Fachschaft Deutsch (für Lehrkräfte)

**https://ratpoison-de.github.io/pags-lernplaner/fachschaft-deutsch/** · Demo ohne Anmeldung: [`?demo`](https://ratpoison-de.github.io/pags-lernplaner/fachschaft-deutsch/?demo) · [Anleitung (PDF)](fachschaft-deutsch/Anleitung-Fachschaft-Deutsch.pdf)

Gemeinsame App der Fachschaft Deutsch. Anders als Lernplaner und Wochenstapel sind die Daten **geteilt**: Alle Mitglieder sehen und bearbeiten dieselben Einträge.

- Bereiche: Übersicht mit Pinnwand, Termine & Fristen (Export als .ics), Aufgaben, Materialpool (Links, Filter nach Klasse 5–10, Niveau G/M/E, Bereich, Art), Lektüren mit Ausleihe, Jahresplanung je Klassenstufe mit Grammatikrahmen, Protokolle mit Beschlüssen, Vereinbarungen, Notenrechner mit gemeinsamem Notenschlüssel, Mitgliederverwaltung, Suche über alles, JSON-Sicherung.
- Beitritt: mit dem Lernplaner-Konto anmelden (oder in der App „Neues Konto“), dann Name und **Fachschafts-Code** eingeben. Die Leitung ändert den Code in der App unter „Fachschaft“.
- Datenbank: [`supabase/fachschaft.sql`](supabase/fachschaft.sql) (Tabellen `fs_codes`, `fs_mitglieder`, `fs_eintraege`). Wer etwas angelegt oder zuletzt geändert hat, setzt die Datenbank selbst.
- Die Tabellen haben eine Spalte `fachschaft`. Eine weitere Fachschaft (z. B. `englisch`) braucht nur einen Eintrag in `fs_codes` und eine Kopie des Ordners mit angepasstem `FS`.

## Korrekturtabelle (für Lehrkräfte)

**https://ratpoison-de.github.io/pags-lernplaner/korrektur/** · [Anleitung mit Bildern (PDF)](korrektur/anleitung.pdf)

Web-Fassung der Excel-Korrekturtabelle mit allen vier Blättern und Erweiterungen:

- **Notenschlüssel** (Blätter „1-8“ und „9-10“): linear mit einstellbarer 50-%-Note, Prozent-Umrechnung oder frei einstellbarer Prozent-Schlüssel; Schnellabfrage, Notengrenzen, Tendenznoten, Druck und Excel-Export.
- **Korrektur:** Punkte je Aufgabe, Note sofort, Notenspiegel, Durchschnitt, Aufgabenanalyse, Drittel-Hinweis und einstellbare Prüfgrenze; Übertragung in die Leistungsübersicht per Knopfdruck.
- **Leistungsübersicht** (Blätter „LEB“ und „LEB Englisch“): gewichtete Noten (Eingabe auch als 2-, 2+, 2-3) bzw. Kompetenzen in Prozent (Listening, Reading, Writing, Mediation, Sprechen).
- **Import** der bisherigen Excel-Datei, **Sicherung** als JSON, Export als .xlsx, offline nutzbar.
- **Keine Anmeldung, keine Cloud:** Namen und Noten bleiben im Browser des Geräts (localStorage). Für ein zweites Gerät die Sicherung herunterladen und dort laden.

## Lehrkraft-Seite

**https://ratpoison-de.github.io/pags-lernplaner/lehrkraft.html**

- Anmeldung mit einem eigenen Lernplaner-Konto, das als Lehrkraft freigeschaltet ist.
- Kontenliste mit Suche, letzter Anmeldung und letztem Speichern. Planer-Inhalte der Schüler sind nicht sichtbar.
- **Neues Passwort:** erzeugt ein gut vorlesbares Startpasswort, meldet alle Geräte des Kontos ab. Beim nächsten Anmelden muss die Schülerin bzw. der Schüler ein eigenes Passwort wählen.
- **Löschen:** nach Eintippen des Benutzernamens, mit allen Daten. Lehrkraft-Konten sind geschützt.

Die Rechte prüft die Datenbank selbst ([`supabase/admin.sql`](supabase/admin.sql)), es liegt kein geheimer Schlüssel im Browser.

### Weitere Lehrkraft freischalten
Die Kollegin bzw. der Kollege legt in der App über „Neues Konto“ ein Konto an. Dann im **SQL Editor**:

```sql
insert into public.admins (user_id)
select id from auth.users where email = 'BENUTZERNAME@lernplaner.pags-kuelsheim.de';
```

## Betrieb

### Passwort zurücksetzen ohne Lehrkraft-Seite
Notfalls im **SQL Editor** (Benutzername und neues Passwort anpassen):

```sql
update auth.users
set encrypted_password = extensions.crypt('NeuesPasswort123', extensions.gen_salt('bf'))
where email = 'benutzername@lernplaner.pags-kuelsheim.de';
```

Die Schülerin bzw. der Schüler meldet sich damit an und ändert das Passwort unter ⋯ → „Passwort ändern“.
(Die Adresse `…@lernplaner.pags-kuelsheim.de` ist nur eine interne Login-Kennung, es werden keine Mails verschickt.)

### Konten ansehen oder löschen
**Authentication → Users**. Schüler können ihr Konto auch selbst löschen (⋯ → „Konto löschen“), dabei werden alle Daten mitgelöscht.

### Neue Registrierungen stoppen
**Authentication → Sign In / Providers → Allow new users to sign up** ausschalten. Bestehende Konten funktionieren weiter.

### Pausiertes Projekt
Kostenlose Supabase-Projekte werden nach einer Woche ohne Nutzung pausiert (z. B. in den Ferien). Im Dashboard auf **Restore project** klicken. Die Daten bleiben erhalten.

## Datenschutz

- Gespeichert werden nur der selbst gewählte Benutzername, das Passwort (verschlüsselt) und die Planer-Einträge.
- Die Schüler werden gebeten, nicht ihren vollen Namen als Benutzernamen zu verwenden.
- Server-Standort: EU (Frankfurt). Supabase bietet einen Auftragsverarbeitungsvertrag (DPA) an.
- Vor dem Einsatz mit Schülerinnen und Schülern: Schulleitung und Datenschutzbeauftragte einbeziehen.

## Dateien

| Datei | Inhalt |
|---|---|
| `index.html` | Die komplette App |
| `config.js` | Verbindung zu Supabase |
| `lehrkraft.html` | Bereich für Lehrkräfte |
| `supabase/schema.sql` | Tabelle, Zugriffsregeln, Konto-Löschfunktion |
| `supabase/admin.sql` | Lehrkraft-Rechte und -Funktionen |
| `wochenstapel/` | Wochenstapel-App mit Manifest und Icons |
| `supabase/wochenstapel.sql` | Tabelle und Zugriffsregeln für den Wochenstapel |
| `lernbegleiter/` | Lernbegleiter-App für Lehrkräfte mit Manifest und Icons |
| `supabase/lernbegleiter.sql` | Tabelle und Zugriffsregeln für den Lernbegleiter |
| `fachschaft-deutsch/` | App der Fachschaft Deutsch mit Manifest, Icons und Anleitung |
| `supabase/fachschaft.sql` | Gemeinsame Fachschafts-Tabellen, Regeln und Funktionen |
| `korrektur/` | Korrekturtabelle für Lehrkräfte mit Manifest, Service Worker, Icons und Anleitung (PDF) |
| `manifest.webmanifest`, `icon-*.png` | „Zum Startbildschirm hinzufügen“ |
