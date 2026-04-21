# Noctalia Shell Setup

Noctalia ist eine Wayland Desktop Shell (basiert auf Quickshell/Qt), die Waybar, Mako und Fuzzel ersetzt.
Unterstützt nativ Niri, Hyprland, Sway u.a.

---

## Änderungen am Repo

### flake.nix
```nix
nixConfig = {
  extra-substituters = [ "https://niri.cachix.org" "https://noctalia.cachix.org" ];
  extra-trusted-public-keys = [
    "niri.cachix.org-1:..."
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];
};

inputs.noctalia = {
  url = "github:noctalia-dev/noctalia-shell";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In outputs für BEIDE Hosts als sharedModule eintragen:
{ home-manager.sharedModules = [ noctalia.homeModules.default ]; }
```

### system/laptop.nix (nur Laptop)
```nix
hardware.bluetooth.enable = true;  # Prerequisite für Noctalia
```

### home/laptop-niri.nix und home/desktop-niri.nix
```nix
# Noctalia aktivieren
programs.noctalia-shell.enable = true;

# Waybar deaktivieren (Konfiguration bleibt als Fallback erhalten)
programs.waybar.enable = false;

# Mako entfernen (Noctalia übernimmt Notifications)
# services.mako Block komplett entfernt
```

Niri autostart (waybar + mako raus, noctalia rein):
```
// Autostart
spawn-at-startup "noctalia-shell"    # WICHTIG: nicht "qs -c noctalia-shell"!
spawn-at-startup "swaybg" ...
# spawn-at-startup "waybar"          ← entfernt
# spawn-at-startup "mako"            ← entfernt
```

Keybindings auf Noctalia IPC umgestellt:
```
Alt+Space   { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
Super+Alt+L { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
```

---

## Erstes Starten — bekanntes Problem

Nach dem ersten Rebuild/Reboot startet noctalia zwar als Prozess, erstellt aber
**keine Layer-Surfaces** (Bar und Dock sind unsichtbar).

`niri msg layers` zeigt dann nur den wallpaper, kein noctalia.

**Fix:** Noctalia einmal manuell killen und neu starten:

```bash
pkill -9 quickshell
sleep 1
noctalia-shell &
```

Danach zeigt `niri msg layers` die Surfaces:
```
Top layer:
  noctalia-background-eDP-1
  noctalia-bar-content-eDP-1
  noctalia-bar-exclusion-top-eDP-1
```

Ab dem nächsten Niri-Neustart funktioniert der Autostart dann zuverlässig.

---

## Einstellungen / Konfiguration

Alle GUI-Einstellungen werden lokal gespeichert (NICHT im Git-Repo):
```
~/.config/noctalia/settings.json   # Bar, Dock, Themes, Widgets, etc.
~/.config/noctalia/plugins.json    # Installierte Plugins
~/.config/noctalia/plugins/        # Plugin-Dateien
```

Beim ersten Start erstellt Noctalia diese Dateien automatisch mit Defaults.

### Einstellungen zwischen Laptop und Desktop synchronisieren

Settings manuell vom Laptop auf den Desktop kopieren:
```bash
scp laptop:~/.config/noctalia/settings.json ~/.config/noctalia/settings.json
```

Oder über Nextcloud synchronisieren.

---

## Nützliche Befehle

```bash
# Starten / Neustarten
noctalia-shell &
pkill -9 quickshell && sleep 1 && noctalia-shell &

# IPC
noctalia-shell ipc call launcher toggle       # Launcher öffnen/schließen
noctalia-shell ipc call lockScreen lock       # Sperrbildschirm
noctalia-shell ipc show                       # Alle IPC-Targets anzeigen

# Diagnose
niri msg layers                               # Prüfen ob Layer-Surfaces aktiv sind
pgrep -a quickshell                           # Prüfen ob Prozess läuft
```

---

## Bekannte Warnungen (harmlos)

- `PowerProfiles service not available` — kein Problem, Laptop nutzt TLP
- `ext-background-effect-v1 not supported` — Blur wird von Niri nicht unterstützt
- `Could not register app ID` — XDG Portal Kleinigkeit, keine Auswirkung
