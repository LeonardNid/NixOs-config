# NixOS Config – Regeln für Claude

## Projektstruktur

```
nixos-config/
├── flake.nix                  # Inputs (nixpkgs, home-manager, claude-code-nix) + Host-Definitionen
├── hosts/
│   ├── leonardn/              # Desktop-PC (hostname: leonardn)
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── laptop/                # Laptop (hostname: laptop)
│       ├── default.nix        # Bindet system/laptop.nix + home/laptop.nix ein
│       └── hardware-configuration.nix
├── system/                    # NixOS-Module (systemweit, root)
│   ├── packages.nix           # Gemeinsame System-Pakete (beide Hosts)
│   ├── desktop.nix            # KDE Plasma 6, SDDM, Auto-Login
│   ├── users.nix              # User leonardn, sudo, Gruppen, Tailscale
│   ├── laptop.nix             # NUR Laptop: TLP, libinput, touchpad, fusuma/uinput
│   ├── networking.nix
│   ├── locale.nix
│   ├── boot.nix
│   ├── hardware.nix
│   ├── audio.nix
│   └── nix-settings.nix
├── home/                      # Home-Manager-Module (user leonardn)
│   ├── default.nix            # Basis: importiert alle shared home-Module
│   ├── packages.nix           # Gemeinsame user-Pakete (beide Hosts)
│   ├── laptop.nix             # NUR Laptop: fusuma, ydotool, nextcloud-client
│   ├── vscode.nix             # VSCode + Copilot Extensions
│   ├── xdg.nix                # MIME-Defaults (Vivaldi als Standard-Browser)
│   ├── git.nix                # Git-Konfiguration
│   ├── shell.nix              # Zsh, starship, zoxide
│   ├── neovim.nix             # Neovim
│   └── scripts.nix            # Shell-Skripte (rebuild)
├── vm/                        # VM/GPU-Passthrough (nur leonardn relevant)
├── scripts/
│   └── bootstrap.sh           # Fresh-Install-Skript
└── documentation/
    └── fresh_install_todo.md  # Schritt-für-Schritt Guide für neue Installs
```

## Regeln

### Laptop vs. Desktop trennen

- **Laptop-spezifische System-Module** gehören in `system/laptop.nix` und werden nur in `hosts/laptop/default.nix` importiert.
- **Laptop-spezifische Home-Module** gehören in `home/laptop.nix` und werden nur in `hosts/laptop/default.nix` eingebunden:
  ```nix
  home-manager.users.leonardn = { imports = [ ../../home/laptop.nix ]; };
  ```
- `system/packages.nix` und `home/packages.nix` sind für **beide Hosts** – nichts Laptop-Spezifisches dort.

### Neue Pakete hinzufügen

- **System-Paket (alle Hosts):** `system/packages.nix`
- **User-Paket (alle Hosts):** `home/packages.nix`
- **Nur Laptop:** `home/laptop.nix` oder `system/laptop.nix`
- Programme die home-manager-Optionen brauchen (vscode, git, etc.) gehören in eigene `home/*.nix` Dateien, nicht in `packages.nix`.

### Rebuild

Das `rebuild`-Skript ist im PATH und macht: git add/commit, nixos-rebuild switch, git push.

```bash
rebuild "beschreibung der änderung"
```

Es nutzt `$(hostname)` – funktioniert auf beiden Hosts automatisch.
