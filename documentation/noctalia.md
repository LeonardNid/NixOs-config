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

---

## App-Icons im Audio-Panel fehlen (lila/schwarze Vierecke)

**Symptom:** Im Audio-Panel (Lautstärken-Tab) zeigen manche Apps lila/schwarze
Vierecke statt Icons — z.B. Chromium oder Scream.

**Ursache:** Noctalia ist Qt/Quickshell-basiert und nutzt ein eigenes Icon-System
(`ThemeIcons.qml`), das **nicht** das GTK-Icon-Theme (Papirus-Dark) liest.
Der Lookup läuft in zwei Stufen:

1. `ThemeIcons.findAppEntry(binaryName)` — sucht in `DesktopEntries` nach einer
   passenden `.desktop`-Datei. Gibt es keine, bricht der Lookup ab und fällt auf
   `application-x-executable` zurück (falsche Icon-Darstellung).
2. Wenn eine `.desktop`-Datei gefunden wird: `Quickshell.iconPath(entry.icon)`
   — Qt durchsucht `$XDG_DATA_DIRS/icons/hicolor/` inkl.
   `~/.local/share/icons/hicolor/`.

Die GTK-Theme-Einstellung (`Papirus-Dark`) wird von Qt ohne konfigurierten
`QT_QPA_PLATFORMTHEME` ignoriert.

**Fix:** Für jede betroffene App sind zwei Dinge nötig:

### 1. Icon-Datei im hicolor-Fallback

In `home/desktop-niri.nix` (und `home/laptop-niri.nix`):

```nix
home.file.".local/share/icons/hicolor/scalable/apps/chromium.svg".source =
  "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark/48x48/apps/chromium-browser.svg";

home.file.".local/share/icons/hicolor/scalable/apps/scream.svg".source =
  "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark/48x48/apps/juk.svg";
```

### 2. Minimale .desktop-Datei

Ohne `.desktop`-Eintrag findet `ThemeIcons.findAppEntry()` nichts und der
`Quickshell.iconPath()`-Aufruf wird nie erreicht:

```nix
home.file.".local/share/applications/chromium.desktop".text = ''
  [Desktop Entry]
  Type=Application
  Name=Chromium
  Icon=chromium
  Exec=chromium
  NoDisplay=true
'';

home.file.".local/share/applications/scream.desktop".text = ''
  [Desktop Entry]
  Type=Application
  Name=Scream
  Icon=scream
  Exec=scream
  NoDisplay=true
'';
```

`NoDisplay=true` verhindert, dass die Einträge im App-Launcher erscheinen.

**Nach dem Rebuild:** Noctalia neu starten damit DesktopEntries neu eingelesen werden:
```bash
pkill -9 quickshell && sleep 1 && noctalia-shell &
```

### Neue App ohne Icon hinzufügen

1. Binary-Namen aus PulseAudio ermitteln (App beim Abspielen):
   ```bash
   pactl list sink-inputs | grep "application.process.binary"
   ```
2. Passendes SVG in Papirus-Dark suchen:
   ```bash
   ls /etc/profiles/per-user/leonardn/share/icons/Papirus-Dark/48x48/apps/ | grep -i <name>
   ```
3. Icon-Datei und `.desktop`-Eintrag nach obigem Muster in `desktop-niri.nix`
   und `laptop-niri.nix` eintragen.
