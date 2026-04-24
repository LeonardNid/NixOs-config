# VS Code Jupyter in Nix-Shell Projekten

## Problem

VS Code kann Jupyter nicht starten, obwohl `ipykernel` und `jupyter` in der venv installiert sind:

```
Jupyter cannot be started. Error attempting to locate Jupyter: 'Kernelspec' module not
installed in the selected interpreter (/path/to/.venv/bin/python).
```

**Ursache:** VS Code startet Python-Prozesse ohne die Nix-Shell-Umgebungsvariablen (kein `LD_LIBRARY_PATH`, kein Nix-PATH). Dadurch schlägt der interne Check fehl, auch wenn alles korrekt installiert ist.

## Lösung

**direnv VS Code Extension installieren:** `mkhl.direnv`

Die Extension liest automatisch die `.envrc` des Projekts und gibt alle Nix-Shell-Variablen an VS Code weiter. Damit hat der Jupyter-Kernel dieselbe Umgebung wie das Terminal.

## Setup-Voraussetzungen

Das Projekt braucht:
- Eine `shell.nix` mit einem `shellHook`, der `.venv` anlegt und aktiviert
- Eine `.envrc` mit `use nix` (via nix-direnv)
- `direnv` im System installiert (`programs.direnv.enable = true` in NixOS-Config)

## Hinweis zu venv-Pfaden

Falls das Projekt verschoben wird, sind die Symlinks in `.venv/bin/` kaputt (hardcodierte Pfade). Lösung:

```bash
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
