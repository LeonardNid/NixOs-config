# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# NixOS Config – Regeln für Claude

## Projektstruktur

```
nixos-config/
├── flake.nix                  # Inputs + Host-Definitionen (leonardn, laptop)
├── hosts/
│   ├── leonardn/              # Desktop-PC: nur "kde" oder "niri", GPU-Passthrough, Corsair-Daemon
│   └── laptop/                # Laptop: "kde", "hyprland", "mango" oder "niri"
├── system/                    # NixOS-Module (systemweit, root)
│   ├── packages.nix           # Gemeinsame System-Pakete (beide Hosts)
│   ├── desktop.nix            # KDE Plasma 6, SDDM
│   ├── hyprland.nix           # Hyprland Compositor (nur Laptop)
│   ├── mango.nix              # Mango WM (nur Laptop)
│   ├── niri.nix               # Niri WM
│   ├── laptop.nix             # NUR Laptop: TLP, Kanata, libinput, Brillo
│   ├── ollama.nix             # Ollama KI-Dienst (beide Hosts)
│   ├── corsair-mouse-daemon.nix  # NUR leonardn: Corsair-Maus-Daemon
│   ├── users.nix              # User leonardn, sudo, Gruppen, Tailscale
│   ├── networking.nix / locale.nix / boot.nix / hardware.nix / audio.nix / nix-settings.nix
├── home/                      # Home-Manager-Module (user leonardn)
│   ├── default.nix            # Gemeinsame Basis (BEIDE Hosts): neovim, git, shell, scripts,
│   │                          #   packages, vscode, xdg, navi, nextcloud, vm/vm.nix
│   ├── packages.nix           # Gemeinsame user-Pakete
│   ├── desktop-niri.nix       # NUR leonardn + Niri: Waybar, Fuzzel, Mako, swaylock, VM-Scripts
│   ├── laptop-kde.nix         # NUR Laptop + KDE: Fusuma-Gesten, KWin-Latency-Fix, Lockscreen
│   ├── laptop-hyprland.nix    # NUR Laptop + Hyprland: Waybar, Wofi, Mako, hyprlock, hypridle
│   ├── laptop-mango.nix       # NUR Laptop + Mango: Waybar, Rofi, Mako, swaylock, swayidle
│   ├── laptop-niri.nix        # NUR Laptop + Niri: Waybar, Fuzzel, Mako, swaylock, swayidle
│   ├── scripts.nix            # Shell-Skripte: rebuild, git-overview, power-menu, waybar-mic-status, …
│   └── vscode.nix / git.nix / shell.nix / neovim.nix / xdg.nix / nextcloud.nix / navi.nix
├── vm/                        # VM/GPU-Passthrough (nur leonardn: Looking Glass, KVM, VFIO)
├── scripts/
│   └── bootstrap.sh
└── documentation/
    └── fresh_install_todo.md
```

## Flake-Inputs

| Input | Zweck |
|---|---|
| `nixpkgs` | nixos-unstable |
| `home-manager` | Home-Manager (folgt nixpkgs) |
| `mango` | Mango WM (nur Laptop) |
| `niri-flake` | Niri WM + cachix |
| `zen-browser` | Zen Browser (beide Hosts) |
| `claude-code-nix` | Claude Code CLI (beide Hosts) |

## Regeln

### Laptop vs. Desktop trennen

- **`home/default.nix`** wird von **beiden** Hosts genutzt – enthält alles Gemeinsame inkl. `nextcloud.nix` und `vm/vm.nix`.
- **Desktop-Auswahl** erfolgt über die Variable `desktop` in `hosts/<host>/default.nix`:

| `desktop` | Laptop System-Modul | Laptop Home-Modul | leonardn Home-Modul |
|---|---|---|---|
| `"kde"` | `system/desktop.nix` | `home/laptop-kde.nix` | _(kein extra Home-Modul)_ |
| `"hyprland"` | `system/hyprland.nix` | `home/laptop-hyprland.nix` | _(nur Laptop)_ |
| `"mango"` | `system/mango.nix` | `home/laptop-mango.nix` | _(nur Laptop)_ |
| `"niri"` | `system/niri.nix` | `home/laptop-niri.nix` | `home/desktop-niri.nix` |

- `system/packages.nix` und `home/packages.nix` sind für **beide Hosts** – nichts Host-Spezifisches dort.
- Leonardn (Desktop-PC) hat **keine** `laptop-*.nix` Home-Module – für Niri wird `home/desktop-niri.nix` verwendet.

### Desktop wechseln

1. In `hosts/<host>/default.nix` die Variable ändern: `desktop = "..."`
2. `rebuild "switch to <desktop>"` ausführen
3. Neu starten → SDDM zeigt die neue Session

### Neue Pakete/Module hinzufügen

- **System-Paket (alle Hosts):** `system/packages.nix`
- **User-Paket (alle Hosts):** `home/packages.nix`
- **Nur leonardn + Niri:** `home/desktop-niri.nix`
- **Nur Laptop + KDE/Hyprland/Mango/Niri:** jeweilige `home/laptop-*.nix`
- Programme mit home-manager-Optionen (vscode, git, etc.) gehören in eigene `home/*.nix` Dateien, nicht in `packages.nix`.

### Rebuild

```bash
rebuild "beschreibung"        # git add/commit + nixos-rebuild switch + git push
rebuild -u "beschreibung"     # wie oben, aber zuerst nix flake update
rebuild                       # Commit-Message "update"
```

Das Skript nutzt `$(hostname)` – funktioniert auf beiden Hosts automatisch. Bei Hyprland auf dem Laptop wird außerdem `hyprctl reload` + `systemctl --user restart hyprpaper` ausgeführt.
