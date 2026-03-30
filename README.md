# NixOS Konfiguration

Dieser Ordner (`/etc/nixos/`) wird als Git-Repository verwaltet und immer aktuell auf GitHub gehalten.

## Rebuild

Nach jeder Änderung an der Konfiguration wird mit dem `rebuild` Befehl gebaut, committet und gepusht:

```bash
rebuild "kurze beschreibung"
```

Das macht automatisch folgendes:
1. Schreibt die Beschreibung + Uhrzeit in `label.txt` (erscheint im Boot-Menü)
2. `git add .` + `git commit` mit der Beschreibung als Commit-Message
3. `sudo nixos-rebuild switch --flake /etc/nixos#leonardn`
4. `git push`

Im Boot-Menü erscheint dann z.B.:
```
Generation 78 NixOS Yarara meine-beschreibung--14:30 (Linux 6.18.18), built on 2026-03-30
```

Ohne Beschreibung wird "update" als Standard verwendet:
```bash
rebuild
```
