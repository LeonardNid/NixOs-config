# Noctalia-Settings synchronisieren (Export/Import)

Erstellt: 2026-06-09

## Problem

Noctalia hat **keinen** eingebauten Export/Import-Knopf. Das `ipc` ist nur das generische
quickshell-IPC (Launcher togglen etc.). Alle Einstellungen liegen aber als **einfache
JSON-Dateien** in `~/.config/noctalia/` — und damit nur lokal auf dem jeweiligen Rechner,
ohne Backup oder Sync zwischen Hosts.

| Datei/Ordner | Inhalt |
|---|---|
| `settings.json` | Hauptconfig: Bar, Dock, OSD, Notifications, Wallpaper, UI … |
| `colors.json` | aktuelle Farben |
| `colorschemes/` | eigene Farbschemata |
| `plugins.json` + `plugins/` | Plugin-Config |

> **Portabel:** `bar.monitors` / `dock.monitors` sind leer (keine Monitor-Namen fest verdrahtet),
> und der Username (`leonardn`) ist auf allen Hosts gleich → die Settings lassen sich 1:1
> zwischen Rechnern übertragen.

## Lösung: Repo-Backup-Skripte

Zwei Skripte in `home/scripts.nix` (auf allen Hosts verfügbar). Der Ordner
`noctalia-settings/` im Repo dient als **versionierter Sync** über git/GitHub. Die Live-Config
unter `~/.config/noctalia` bleibt eine normale schreibbare Datei (bewusst **nicht** per Nix
verwaltet — sonst könnte Noctalia sie nicht zur Laufzeit ändern).

### `noctalia-save` — sichern

```
noctalia-save
```
- kopiert `~/.config/noctalia/` → `<repo>/noctalia-settings/` (rsync, mit `--delete`)
- committet **nur** den `noctalia-settings/`-Ordner und pusht nach GitHub
- macht nichts, wenn sich nichts geändert hat

### `noctalia-load` — einspielen

```
noctalia-load
```
- holt den neuesten Stand aus `origin` (`git pull --rebase --autostash`, best effort)
- **stoppt** Noctalia (`pkill -f quickshell`), damit es beim Beenden nichts überschreibt
- spielt `<repo>/noctalia-settings/` → `~/.config/noctalia/` ein
- startet Noctalia in der laufenden Session neu

## In `rebuild` integriert (Voll-Sync, automatisch)

`rebuild` macht den Sync inzwischen **automatisch** in beide Richtungen — die Skripte
`noctalia-save`/`noctalia-load` bleiben für manuelle Einzelaktionen erhalten.

- **Speichern (vor dem Commit):** `~/.config/noctalia` wird ins Repo gespiegelt und landet im
  normalen rebuild-Commit + Push. Geänderte Noctalia-Settings werden also bei jedem `rebuild`
  mitversioniert.
- **Laden + Neustart (nach dem Build):** `rebuild` vergleicht den git-Objekt-Hash von
  `noctalia-settings` **vor und nach dem `git pull`**. Nur wenn der Pull echte neue Settings
  (von einem anderen Rechner) gebracht hat, werden sie eingespielt und Noctalia neu gestartet.

**Datensicherheit / „nur bei Änderung neu starten":**
- Erkennung über die Pull-Hashes ⇒ ein ungespeicherter lokaler Stand wird **nie** durch einen
  unrelated `rebuild` überschrieben, und Noctalia wird nicht unnötig neu gestartet.
- Greift nur, wenn `rebuild` als echter User (nicht unter `sudo`) läuft und `~/.config/noctalia`
  existiert. Neustart nur, wenn Noctalia (quickshell) gerade läuft.
- Gleichzeitiges Ändern auf zwei Rechnern kann beim `pull --rebase` einen Merge-Konflikt in
  `settings.json` geben — das fängt der normale rebuild-Konflikt-Dialog ab.

## Typischer Ablauf

- **Mit `rebuild` (automatisch):** Auf Rechner A einstellen → `rebuild "…"` (sichert+pusht).
  Auf Rechner B → `rebuild "…"` (zieht A's Settings rein + startet Noctalia neu, sofern geändert).
- **Manuell (ohne rebuild):**
  1. Auf Rechner A Noctalia einstellen → `noctalia-save`
  2. Auf Rechner B → `noctalia-load` → übernimmt die Settings + startet Noctalia neu

## Hinweise

- **Baseline:** Der erste `noctalia-save` legt den Ausgangsstand im Repo an (hier: der frische
  Mini-PC-Install, Stand 2026-06-09).
- `noctalia-load` überschreibt die **lokalen** Settings vollständig (`rsync --delete`). Vorher
  ggf. selbst `noctalia-save`, wenn der lokale Stand erhaltenswert ist.
- Die Skripte fassen nur den `noctalia-settings/`-Pfad im git an — unrelated Änderungen im Repo
  bleiben unberührt.
