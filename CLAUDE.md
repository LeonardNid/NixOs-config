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
│   ├── desktop.nix            # KDE Plasma 6, SDDM (beide Hosts)
│   ├── hyprland.nix           # Hyprland Compositor, SDDM (nur Laptop via desktop-Variable)
│   ├── users.nix              # User leonardn, sudo, Gruppen, Tailscale
│   ├── laptop.nix             # NUR Laptop: TLP, Kanata, libinput, Brillo (desktop-agnostisch)
│   ├── networking.nix
│   ├── locale.nix
│   ├── boot.nix
│   ├── hardware.nix
│   ├── audio.nix
│   └── nix-settings.nix
├── home/                      # Home-Manager-Module (user leonardn)
│   ├── default.nix            # Basis: importiert alle shared home-Module
│   ├── packages.nix           # Gemeinsame user-Pakete (beide Hosts)
│   ├── nextcloud.nix          # Nextcloud (beide Hosts)
│   ├── laptop-kde.nix         # NUR Laptop + KDE: Fusuma-Gesten, KWin-Latency-Fix, Lockscreen
│   ├── laptop-hyprland.nix    # NUR Laptop + Hyprland: Waybar, Wofi, Mako, hyprlock, hypridle
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

- **Laptop-spezifische System-Module** gehören in `system/laptop.nix` (desktop-agnostisch).
- **Desktop-Auswahl** erfolgt über die Variable `desktop` in `hosts/laptop/default.nix`:
  - `desktop = "kde"` → importiert `system/desktop.nix` + `home/laptop-kde.nix`
  - `desktop = "hyprland"` → importiert `system/hyprland.nix` + `home/laptop-hyprland.nix`
  - `desktop = "mango"` → importiert `system/mango.nix` + `home/laptop-mango.nix`
  - `home/nextcloud.nix` wird immer importiert
- `system/packages.nix` und `home/packages.nix` sind für **beide Hosts** – nichts Laptop-Spezifisches dort.

### Desktop wechseln (Laptop)

1. In `hosts/laptop/default.nix` die Variable ändern: `desktop = "kde"` / `"hyprland"` / `"mango"`
2. `rebuild "switch to mango"` ausführen
3. Neu starten → SDDM zeigt die neue Session

### Neue Pakete hinzufügen

- **System-Paket (alle Hosts):** `system/packages.nix`
- **User-Paket (alle Hosts):** `home/packages.nix`
- **Nextcloud (beide Hosts):** `home/nextcloud.nix`
- **Nur Laptop + KDE:** `home/laptop-kde.nix`
- **Nur Laptop + Hyprland:** `home/laptop-hyprland.nix`
- **Nur Laptop + Mango:** `home/laptop-mango.nix`
- Programme die home-manager-Optionen brauchen (vscode, git, etc.) gehören in eigene `home/*.nix` Dateien, nicht in `packages.nix`.

### Rebuild

Das `rebuild`-Skript ist im PATH und macht: git add/commit, nixos-rebuild switch, git push.

```bash
rebuild "beschreibung der änderung"
```

Es nutzt `$(hostname)` – funktioniert auf beiden Hosts automatisch.
