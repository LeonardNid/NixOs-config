# Git & Forgejo

## Grundbefehle

```bash
git status          # Was hat sich geändert?
git log --oneline   # Commit-Historie (kompakt)
git diff            # Was wurde geändert (noch nicht gestaged)?
git diff --staged   # Was wurde geändert (bereits gestaged)?

git add datei.txt      # Einzelne Datei stagen
git add .              # Alle Änderungen stagen
git commit -m "Nachricht"

git push               # Lokale Commits hochladen
git pull               # Remote-Änderungen holen + mergen
git fetch              # Remote-Änderungen holen (ohne merge)

git branch                  # Alle lokalen Branches anzeigen
git checkout -b feature-xy  # Neuen Branch erstellen + wechseln
git checkout main
git merge feature-xy
git remote -v               # Remote-URL anzeigen
```

---

## Forgejo Setup (einmalig pro Rechner)

**1. SSH-Key erstellen**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/forgejo
```

**2. Public Key in Forgejo hinterlegen**

Inhalt von `~/.ssh/forgejo.pub` unter Settings → SSH Keys → Add Key einfügen.

**3. SSH-Config anlegen** (`~/.ssh/config`)
```
Host leoserver.tail6bb5cd.ts.net
    IdentityFile ~/.ssh/forgejo
    Port 2222
```

---

## Neues Projekt anlegen

### Dateistruktur

```
mein-projekt/
├── shell.nix          # Nix-Entwicklungsumgebung
├── .envrc             # direnv-Integration (lädt shell.nix automatisch)
├── .gitignore
├── requirements.txt   # Python-Abhängigkeiten (falls Python-Projekt)
└── ...
```

### Checkliste

- [ ] Ordner anlegen
- [ ] `shell.nix` erstellen (Vorlage unten)
- [ ] `.envrc` mit `use nix` erstellen, dann `direnv allow`
- [ ] `.gitignore` erstellen (Vorlage unten)
- [ ] Repo auf Forgejo anlegen (Web-UI oder API)
- [ ] Git initialisieren und pushen:

```bash
git init
git checkout -b main
git add .
git commit -m "first commit"
git remote add origin ssh://git@leoserver.tail6bb5cd.ts.net:2222/Draonel/mein-projekt.git
git push -u origin main
```

### Repo auf Forgejo per API anlegen

```bash
curl -X POST "https://leoserver.tail6bb5cd.ts.net:8095/api/v1/user/repos" \
  -H "Authorization: token DEINTOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "mein-repo", "private": true}'
```

---

## Projekt auf neuem Rechner klonen

```bash
git clone ssh://git@leoserver.tail6bb5cd.ts.net:2222/Draonel/mein-projekt.git ~/gitprojs/mein-projekt
cd ~/gitprojs/mein-projekt
direnv allow
```

> **Wichtig:** Die `shell.nix` erstellt nur die venv — Pakete sind noch nicht installiert.
> Nach dem ersten `cd` in den Ordner (direnv aktiviert die Umgebung):
> ```bash
> pip install -r requirements.txt
> ```

---

## shell.nix Vorlagen

### Python-Projekt (mit pip/venv)

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.python312
    pkgs.python312Packages.pip
    pkgs.python312Packages.setuptools
    pkgs.python312Packages.wheel

    # Systembibliotheken für native Python-Pakete (torch, opencv etc.)
    pkgs.zlib
    pkgs.stdenv.cc.cc.lib
    pkgs.libGL
  ];

  shellHook = ''
    if [ ! -d ".venv" ]; then
      echo "Erstelle neues venv..."
      python3 -m venv .venv
    fi

    source .venv/bin/activate

    python -m ipykernel install --user \
      --name "$(basename $PWD)" \
      --display-name ".venv ($(python --version | cut -d' ' -f2))" \
      2>/dev/null

    export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.libGL}/lib:$LD_LIBRARY_PATH"

    echo "Python-Umgebung aktiv: $(which python) ($(python --version))"
    echo "Pakete installieren: pip install -r requirements.txt"
  '';
}
```

### Einfaches Projekt (kein Python)

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    # pkgs.nodejs
    # pkgs.rustc
  ];
}
```

---

## .gitignore Vorlagen

### Python-Projekt

```gitignore
# Python
.venv/
__pycache__/
*.py[cod]
*.egg-info/

# Jupyter
.ipynb_checkpoints/

# ML / Training
lightning_logs/
aim_logs/
*.ckpt
*.pt
*.pth

# Daten
data/
datasets/

# Nix
result
```

### Allgemein

```gitignore
# Nix
result

# Editor
.vscode/
*.swp
```

---

## Alle Projekte verwalten (`~/gitprojs/`)

```bash
git-overview    # Projekte mit uncommitted changes oder unpushed commits anzeigen
git-push-all    # Alle Projekte mit Änderungen committen und pushen
git-pull-all    # Alle Projekte mit neuen Remote-Commits pullen
```

> `git-pull-all` klont **keine** neuen Repos — nur bereits vorhandene Ordner werden gepullt.
> Neue Repos müssen erst manuell geklont werden (siehe "Projekt auf neuem Rechner klonen").

**`git-push-all` Verhalten:**
- Modifizierte/gelöschte Dateien (`git add -u`) werden automatisch committet (Message: `"update"`)
- Untracked files (`??`) werden **nicht** automatisch hinzugefügt — manuell mit `git add` + `git commit`

---

## Gitignore-Falle: bereits getrackte Dateien

Wenn eine Datei schon committed war bevor sie in `.gitignore` stand, ignoriert git sie trotzdem weiterhin. Fix:

```bash
git rm -r --cached .direnv/
git commit -m "remove .direnv from tracking"
```
