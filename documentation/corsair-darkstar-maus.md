# Corsair Darkstar Wireless - Maus-Setup unter NixOS

## Zusammenfassung

Die Corsair Darkstar Wireless verbindet sich uber den **Corsair Slipstream Wireless USB Receiver** (USB `1b1c:1bdc`). Unter Linux sendet die Maus-Firmware fehlerhafte Scroll-Events, die ohne Korrektur zu ruckeligem Scrollen, falscher Scroll-Richtung und Problemen bei schnellem Scrollen fuhren. Ausserdem sind die Extra-Tasten der Maus unter Linux nicht konfigurierbar (iCUE nur Windows/Mac).

Ein Python-Service (`corsair-mouse-daemon`) fangt die rohen Events ab, normalisiert Scroll-Events, remappt Extra-Tasten und gibt alles uber ein virtuelles Gerat (`CorsairFixed`) weiter. Sowohl Linux (KDE Plasma) als auch die Windows-VM nutzen dieses korrigierte Gerat.

## Das Problem

Die Maus-Firmware sendet pro Scroll-Raste:
- `REL_WHEEL = 10` (normal ware 1)
- `REL_WHEEL_HI_RES = 1200` (normal ware 120)

Auswirkungen:
- **10x zu schnelles Scrollen**
- **Richtungsumkehr** (Scroll-Encoder-Bounce: kurze Gegensignale innerhalb von Millisekunden)
- **Schnelles Scrollen registriert nicht** (Hi-Res und Legacy Events konfligieren)

Corsair-Software (iCUE) ist nur fur Windows/Mac verfugbar. `ckb-next` (Open-Source-Alternative) erkennt die Darkstar uber Slipstream nicht (offenes Issue ckb-next#1078).

## Die Losung

### Architektur

```
Corsair Darkstar (Hardware)
        |
        v
Slipstream Receiver
  event11: Maus (BTN_LEFT, BTN_RIGHT, BTN_SIDE, BTN_EXTRA, Scroll)
  event14: Keyboard (Extra-Tasten via iCUE als KEY_1-KEY_8)
        |
        | (beide grabbed - exklusiv von corsair-mouse-daemon gelesen)
        v
corsair-mouse-daemon.py (Python evdev Service)
  Scroll-Fix:
  - Blockiert raw REL_WHEEL (verhindert Doppelzahlung)
  - Nutzt REL_WHEEL_HI_RES als Primarquelle
  - Akkumuliert 120 Hi-Res-Einheiten = 1 Scroll-Schritt
  - Entprellt Richtungswechsel (< 30ms = Bounce)
  Button-Remap:
  - Remappt Extra-Tasten auf Keyboard-Shortcuts/Modifier
  - Unterstuetzt Single-Key, Combos und Block-Actions
        |
        v
CorsairFixed (/dev/input/corsair-fixed) - virtuelles Gerat
        |
        +---> KDE Plasma (Wayland) - normales Scrollen + remappte Tasten
        |
        +---> Windows VM (QEMU evdev passthrough)
```

### iCUE Konfiguration (Firmware)

Die Extra-Tasten der Maus werden in iCUE (via Windows-VM + USB-Passthrough) auf Keyboard-Keys gemappt:

| Physische Taste | iCUE-Mapping | Hinweis |
|----------------|-------------|---------|
| Vorne oben | KEY_1 | "Simuliere Gedrueckthalten" AUS |
| Vorne unten | KEY_2 | "Simuliere Gedrueckthalten" AUS |
| Hinten oben | KEY_3 | "Simuliere Gedrueckthalten" AUS |
| Hinten unten | KEY_4 | "Simuliere Gedrueckthalten" AUS |
| DPI vorne | KEY_5 | "Simuliere Gedrueckthalten" AUS |
| DPI hinten | KEY_6 | "Simuliere Gedrueckthalten" AUS |
| Profil vorne | KEY_7 | "Simuliere Gedrueckthalten" AUS |
| Profil hinten | KEY_8 | "Simuliere Gedrueckthalten" AUS |

**Wichtig:** "Simuliere Gedrueckthalten" muss in iCUE AUSGESCHALTET sein, sonst sendet die Firmware sofort DOWN+UP statt korrektem Hold-Verhalten.

### Button-Remapping

Im Script `corsair-mouse-daemon.py` definiert als `BUTTON_MAP`:

```python
BUTTON_MAP = {
    ecodes.KEY_2: ecodes.KEY_LEFTMETA,  # Vorne unten -> Super
    ecodes.KEY_5: ecodes.KEY_MUTE,      # DPI vorne -> Mute
}
```

Unterstuetzte Action-Typen:
- `int` — Einzelne Taste (z.B. `ecodes.KEY_LEFTMETA`)
- `[int, ...]` — Keyboard-Combo, Modifier zuerst (z.B. `[ecodes.KEY_LEFTCTRL, ecodes.KEY_C]`)
- `None` — Taste blockieren

### Beteiligte Dateien

| Datei | Zweck |
|-------|-------|
| `scripts/corsair-mouse-daemon.py` | Python-Script: Scroll-Fix + Button-Remap |
| `system/corsair-mouse-daemon.nix` | systemd-Service Definition |
| `hosts/leonardn/default.nix` | Importiert das Nix-Modul |

### systemd-Service

Definiert in `system/corsair-mouse-daemon.nix`:

```nix
systemd.services.corsair-mouse-daemon = let
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
in {
  description = "Corsair Darkstar Mouse Daemon (scroll fix + button remap)";
  wantedBy = [ "multi-user.target" ];
  after = [ "systemd-udev-settle.service" ];
  serviceConfig = {
    Type = "simple";
    Restart = "always";
    RestartSec = 3;
    ExecStart = "${python}/bin/python3 ${../scripts/corsair-mouse-daemon.py}";
  };
};
```

Service-Befehle:
```bash
systemctl status corsair-mouse-daemon   # Status pruefen
sudo systemctl restart corsair-mouse-daemon  # Neustarten
journalctl -u corsair-mouse-daemon      # Logs anzeigen
```

### udev-Regel

Erstellt einen stabilen Symlink fur das virtuelle Gerat:

```
KERNEL=="event*", ATTRS{name}=="CorsairFixed", SYMLINK+="input/corsair-fixed", GROUP="kvm", MODE="0666", TAG+="uaccess"
```

- `/dev/input/corsair-fixed` zeigt immer auf das CorsairFixed-Gerat (Event-Nummer ist dynamisch)
- `MODE="0666"` damit QEMU (qemu-libvirtd User) das Gerat lesen kann

### Windows VM Integration

Die VM `windows11` nutzt das korrigierte Gerat per QEMU evdev passthrough:

```xml
<qemu:arg value='input-linux,id=mouse,evdev=/dev/input/corsair-fixed'/>
```

Die `cgroup_device_acl` in der libvirtd-Konfiguration erlaubt event0-event299 um dynamische Event-Nummern des virtuellen Gerats abzudecken.

### KDE Konfiguration

In `~/.config/kcminputrc`:
- Das originale Corsair-Gerat ist **deaktiviert** (`Enabled=false`)
- `CorsairFixed` ist **aktiviert** mit angepasstem `ScrollFactor`

## Tuning-Parameter

Im Script `corsair-mouse-daemon.py`:

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| `HIRES_PER_STEP` | `120` | Hi-Res-Einheiten pro Scroll-Schritt (Standard-Konvention) |
| `DEBOUNCE_MS` | `30` | Richtungswechsel innerhalb dieses Fensters werden ignoriert |

Falls das Scrollen zu schnell/langsam ist: `ScrollFactor` in KDE Systemeinstellungen anpassen.

## Debugging

```bash
# Service-Logs anzeigen:
journalctl -u corsair-mouse-daemon -f

# Events vom korrigierten virtuellen Gerat anzeigen:
nix-shell -p evtest --run "sudo evtest /dev/input/corsair-fixed"

# Alle Maustasten entdecken (Service muss gestoppt sein):
sudo systemctl stop corsair-mouse-daemon
nix-shell -p 'python3.withPackages(ps: [ps.evdev])' --run \
  "sudo python3 ~/nixos-config/scripts/corsair-mouse-daemon.py --discover"

# Pruefen ob das virtuelle Gerat existiert:
cat /proc/bus/input/devices | grep -A5 CorsairFixed

# Pruefen ob der Symlink existiert:
ls -la /dev/input/corsair-fixed
```

## Was nicht funktioniert hat

| Ansatz | Ergebnis |
|--------|----------|
| `ckb-next` | Erkennt Darkstar uber Slipstream nicht |
| iCUE (Windows VM) | Keine Scroll-Einstellungen fur Darkstar verfugbar |
| libinput Quirks (`AttrEventCode=-REL_WHEEL_HI_RES`) | Teilweise besser, aber Richtungsumkehr blieb |
| `evsieve` (Hi-Res blockieren) | Deutliche Verbesserung, aber kann Werte nicht skalieren |
| KDE `ScrollFactor` allein | Hilft bei Geschwindigkeit, nicht bei Richtungsumkehr |
| Separates virtuelles Keyboard fuer Remaps | Modifier funktionieren nicht Cross-Device unter Wayland |
| iCUE "Simuliere Gedrueckthalten" AN | Sendet sofort DOWN+UP, Hold funktioniert nicht |
