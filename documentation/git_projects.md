# Projekt-Ordner Struktur

Ein neues Projekt besteht aus folgenden Dateien:

```
mein-projekt/
├── shell.nix          # Nix-Entwicklungsumgebung
├── .envrc             # direnv-Integration (lädt shell.nix automatisch)
├── .gitignore         # Dateien die nicht ins Repo sollen
├── requirements.txt   # Python-Abhängigkeiten (falls Python-Projekt)
└── ...                # eigentlicher Projektcode
```

---

## 1. Git initialisieren

```bash
cd mein-projekt
git init
git checkout -b main
git add .
git commit -m "first commit"
git remote add origin ssh://git@leoserver.tail6bb5cd.ts.net:2222/Draonel/mein-projekt.git
git push -u origin main
```

---

## 2. shell.nix

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
    # venv anlegen falls noch nicht vorhanden
    if [ ! -d ".venv" ]; then
      echo "Erstelle neues venv..."
      python3 -m venv .venv
    fi

    source .venv/bin/activate

    # Jupyter-Kernel registrieren (einmalig, für VS Code)
    python -m ipykernel install --user \
      --name "$(basename $PWD)" \
      --display-name ".venv ($(python --version | cut -d' ' -f2))" \
      2>/dev/null

    # Shared libs für native Pakete
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
    # gewünschte Tools eintragen, z.B.:
    # pkgs.nodejs
    # pkgs.rustc
    # pkgs.cargo
  ];
}
```

---

## 3. .envrc

Sorgt dafür dass die nix-shell automatisch aktiviert wird wenn man in den Ordner wechselt (kein `nix-shell --run "code ."` mehr nötig).

```bash
use nix
```

Einmalig nach dem Erstellen freischalten:
```bash
direnv allow
```

---

## 4. .gitignore

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

# Daten (große Dateien gehören nicht ins Repo)
data/
datasets/

# Nix
result
```

### Allgemein (kein Python)

```gitignore
# Nix
result

# Editor
.vscode/
*.swp
```

---

## 5. Gitignore-Falle: bereits getrackte Dateien

Wenn eine Datei/Ordner schon committed war bevor sie in `.gitignore` stand, ignoriert git sie trotzdem weiterhin. Fix:

```bash
git rm -r --cached .direnv/   # Beispiel für .direnv
git commit -m "remove .direnv from tracking"
```

Danach greift `.gitignore` wie erwartet.

---

## 6. Übersicht & Pushen aller Projekte

Alle Projekte liegen in `~/gitprojs/`. Zwei Scripts stehen zur Verfügung:

```bash
git-overview    # zeigt alle Projekte mit uncommitted changes oder unpushed commits
git-push-all    # pusht alle Projekte die unpushed commits haben
```

**Wichtig:** `git-push-all` pusht nur Projekte mit vorhandenen unpushed **commits**.
Ungestage Änderungen müssen vorher manuell mit `git add` + `git commit` committed werden.

---

## 7. Checkliste für ein neues Projekt

- [ ] Ordner anlegen
- [ ] `shell.nix` erstellen
- [ ] `.envrc` mit `use nix` erstellen, dann `direnv allow`
- [ ] `.gitignore` erstellen
- [ ] `git init && git checkout -b main`
- [ ] Repo auf Forgejo anlegen (Web-UI oder API)
- [ ] Remote setzen und pushen
