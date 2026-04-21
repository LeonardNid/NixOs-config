# Noctalia Shell Setup

Noctalia ist eine Wayland Desktop Shell (basiert auf Quickshell/Qt), die Waybar, Mako und Fuzzel ersetzt.
Unterstützt nativ Niri, Hyprland, Sway u.a.

## Was wurde geändert

### flake.nix
- Noctalia Cachix hinzugefügt (`https://noctalia.cachix.org`)
- Flake-Input `noctalia` hinzugefügt (`github:noctalia-dev/noctalia-shell`)
- Home-Manager-Modul für Laptop registriert: `noctalia.homeModules.default` als `sharedModule`

### system/laptop.nix
- `hardware.bluetooth.enable = true` — Prerequisite für Noctalia

### home/laptop-niri.nix
- `programs.noctalia-shell.enable = true`
- `programs.waybar.enable = false` (deaktiviert, Konfiguration bleibt als Fallback erhalten)
- `services.mako` entfernt (Noctalia übernimmt Notifications)
- `spawn-at-startup "waybar"` und `spawn-at-startup "mako"` entfernt
- `spawn-at-startup "noctalia-shell"` hinzugefügt
- Keybindings auf Noctalia IPC umgestellt:
  - `Alt+Space` → Launcher: `noctalia-shell ipc call launcher toggle`
  - `Super+Alt+L` → Sperrbildschirm: `noctalia-shell ipc call lockScreen lock`

## Einstellungen / Konfiguration

Noctalia speichert alle GUI-Einstellungen lokal unter:
```
~/.config/noctalia/settings.json   # Alle Einstellungen (Bar, Dock, Themes, etc.)
~/.config/noctalia/plugins.json    # Installierte Plugins
~/.config/noctalia/plugins/        # Plugin-Dateien
```

Diese Dateien sind NICHT im nixos-config Repo. Bei einer Neuinstallation oder beim
Übertragen auf den Desktop müssen sie manuell kopiert werden.

## Noctalia auf dem Desktop aktivieren

1. In `flake.nix` das `noctalia.homeModules.default` auch zu `nixosConfigurations.leonardn` hinzufügen
2. In `home/desktop-niri.nix` analog zu laptop-niri.nix:
   - `programs.noctalia-shell.enable = true`
   - `programs.waybar.enable = false`
   - `spawn-at-startup "noctalia-shell"` statt `spawn-at-startup "waybar"` / `spawn-at-startup "mako"`
   - Keybindings umstellen
3. `~/.config/noctalia/settings.json` vom Laptop auf den Desktop kopieren (optional, für gleiche Einstellungen)
4. `rebuild "noctalia desktop"`

## Bekannte Warnungen (harmlos)

- `PowerProfiles service not available` — kein Problem, Laptop nutzt TLP
- `ext-background-effect-v1 not supported` — Blur-Effekt wird von Niri nicht unterstützt
- `Could not register app ID` — XDG Portal Kleinigkeit, keine Auswirkung

## Noctalia manuell starten / neustarten

```bash
noctalia-shell &           # Starten
pkill -9 quickshell        # Beenden
```

## Nützliche IPC-Befehle

```bash
noctalia-shell ipc call launcher toggle       # Launcher öffnen/schließen
noctalia-shell ipc call lockScreen lock       # Sperrbildschirm
noctalia-shell ipc show                       # Alle verfügbaren IPC-Targets anzeigen
```
