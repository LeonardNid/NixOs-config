# nc-pick — Datei-Picker für Browser-Uploads

## Problem

Browser-Upload-Felder (z.B. Claude, Nextcloud Web) akzeptieren keine Clipboard-Dateien — man muss Dateien per Drag-and-Drop einwerfen. Der alte Workflow erforderte manuelles Navigieren in Dolphin.

## Lösung

`nc-pick` öffnet ein floating Kitty-Terminal mit fzf zum Durchsuchen von `~`. Ausgewählte Dateien landen als Symlinks in einem Staging-Ordner, Dolphin öffnet sich direkt mit allem vorselektiert.

## Workflow

1. `Mod+Shift+E` drücken
2. Floating Terminal öffnet sich mit fzf
3. Tippen zum Filtern (echtes Fuzzy-Matching), rechts Preview mit Syntax-Highlighting
4. **Tab** zum Markieren mehrerer Dateien, **Shift+Tab** zum Demarkieren
5. **Enter** bestätigen
6. Dolphin öffnet sich mit allen Dateien markiert (`Ctrl+A` automatisch)
7. Einmal in den Browser ziehen — fertig

## Technische Details

**Script:** `home/scripts.nix` → `nc-pick`

- `fd` durchsucht `~` rekursiv (ohne `node_modules`, `target`, `.git`)
- fzf zeigt relative Pfade ab `~/...` (`--with-nth "4.."` schneidet `/home/leonardn/` ab)
- Ausgewählte Dateien → Symlinks in `~/.cache/nc-pick/` (wird bei jedem Start geleert)
- Namenskonflikte werden automatisch aufgelöst (`datei_1.pdf`, `datei_2.pdf`, ...)
- `setsid dolphin` entkoppelt Dolphin vom Terminal → bleibt offen nach Terminal-Close
- `wtype -M ctrl a -m ctrl` schickt Ctrl+A an Dolphin nach 500ms

**Keybind:** `Mod+Shift+E` in `home/desktop-niri.nix` und `home/laptop-niri.nix`

**Window Rule:** Kitty mit Titel `nc-pick` öffnet floating (1100×700px)

**Abhängigkeiten:** `fd`, `fzf`, `bat`, `wtype`, `dolphin` (alle in `home/packages.nix`)
