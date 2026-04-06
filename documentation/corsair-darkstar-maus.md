# Corsair Darkstar Wireless - Maus-Setup unter NixOS

## Zusammenfassung

Die Corsair Darkstar Wireless verbindet sich uber den **Corsair Slipstream Wireless USB Receiver** (USB `1b1c:1bdc`). Unter Linux hat die Maus zwei Hardware-Probleme beim Scrollen:

1. **Encoder-Bounce**: Der Scroll-Encoder sendet kurze Gegensignale (Richtungsumkehr) innerhalb von 40-80ms nach echten Events
2. **Verlorene Ticks bei schnellem Scrollen**: Der Encoder verpasst physische Rasten bei hoher Drehgeschwindigkeit (bestatigt durch evtest am Rohgerat)

Die Scroll-**Werte** selbst sind korrekt und standardkonform (`REL_WHEEL=±1`, `REL_WHEEL_HI_RES=±120` pro Raste) — identisch mit einer Logitech-Referenzmaus. Die fruhere Annahme von 10x-Werten war falsch.

Ein Python-Service (`corsair-mouse-daemon`) fangt die rohen Events ab, filtert Encoder-Bounce, wendet Scroll-Beschleunigung an, remappt Extra-Tasten und gibt alles uber ein virtuelles Gerat (`CorsairFixed`) weiter.

## Die Probleme im Detail

### Encoder-Bounce (Richtungsumkehr)

Bei schnellem Scrollen sendet der Encoder vereinzelte Events in die falsche Richtung:

```
evtest-Ausgabe (Corsair, schnelles Scrollen nach oben):
469.630: REL_WHEEL_HI_RES = +120   ← echt (UP)
469.712: REL_WHEEL_HI_RES = -120   ← BOUNCE (82ms spater, DOWN)
469.733: REL_WHEEL_HI_RES = +120   ← zuruck zur echten Richtung (21ms)
```

Die Logitech-Referenzmaus (USB Optical Mouse, `046d:c077`) zeigt **keine** solchen Bounces.

### Verlorene Encoder-Ticks

Bei sehr schnellem Drehen registriert der Encoder nicht alle physischen Rasten. Dies passiert bereits auf Hardware/Firmware-Ebene — selbst `evtest` direkt am Rohgerat (`/dev/input/event8`) zeigt weniger Events als physisch ausgefuhrt.

- USB Polling-Rate: `bInterval=1` = 1000Hz (Maximum, nicht der Engpass)
- Firmware batcht teilweise: bei hoher Geschwindigkeit `REL_WHEEL=2, HI_RES=240` statt einzelner Events
- Encoder-Hardware ist der limitierende Faktor

### Vergleich mit Logitech-Referenzmaus

| Eigenschaft | Logitech USB Optical | Corsair Darkstar |
|---|---|---|
| Werte pro Raste | `REL_WHEEL=±1, HI_RES=±120` | `REL_WHEEL=±1, HI_RES=±120` (identisch) |
| Encoder-Bounce | Keine | Ja (40-80ms Gegensignale) |
| Verlorene Ticks | Keine | Ja, bei sehr schnellem Scrollen |
| REL_HWHEEL_HI_RES | Nein | Ja |
| USB Polling | `bInterval=1` (1000Hz) | `bInterval=1` (1000Hz) |

## Die Losung

### Architektur

```
Corsair Darkstar (Hardware)
        |
        v
Slipstream Receiver (USB 1b1c:1bdc)
  event8:  Maus (BTN_LEFT, BTN_RIGHT, BTN_SIDE, BTN_EXTRA, Scroll)
  event11: Keyboard (Extra-Tasten via iCUE als KEY_1-KEY_8)
        |
        | (beide grabbed — exklusiv von corsair-mouse-daemon gelesen)
        v
corsair-mouse-daemon.py (Python evdev Service)
  1. Bounce-Filter (DIR_CONFIRM):
     - Einzelne Richtungsumkehr-Events werden gehalten
     - Erst nach 2 aufeinanderfolgenden Events in neuer Richtung
       wird Richtungswechsel akzeptiert
     - Einzelne Bounces werden verworfen
  2. Scroll-Beschleunigung (ACCEL):
     - Kompensiert verlorene Encoder-Ticks bei schnellem Scrollen
     - Lineare Rampe: 1.0x (langsam, dt>100ms) bis 3.0x (schnell, dt→0ms)
  3. HI_RES-Forwarding:
     - Emittiert REL_WHEEL_HI_RES + REL_WHEEL (beide)
     - Compositor kann Smooth Scrolling nutzen
  4. Button-Remap:
     - Remappt Extra-Tasten auf Keyboard-Shortcuts/Modifier
        |
        v
CorsairFixed (/dev/input/corsair-fixed) — virtuelles Gerat
        |
        +---> KDE Plasma / Hyprland (Wayland) — Smooth Scrolling + remappte Tasten
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
    ecodes.KEY_5: [[ecodes.KEY_MUTE], [ecodes.KEY_LEFTMETA, ecodes.KEY_MUTE]],  # DPI vorne -> Mute, dann Super+Mute
    ecodes.KEY_6: [ecodes.KEY_LEFTMETA, ecodes.KEY_MUTE],  # DPI hinten -> Super+Mute
}
```

Unterstuetzte Action-Typen:
- `int` — Einzelne Taste (z.B. `ecodes.KEY_LEFTMETA`)
- `[int, ...]` — Keyboard-Combo, Modifier zuerst (z.B. `[ecodes.KEY_LEFTCTRL, ecodes.KEY_C]`)
- `[[...], [...]]` — Macro: Sequenz von Combos, jede wird einzeln DOWN+UP gesendet
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
| `DIR_CONFIRM` | `2` | Anzahl aufeinanderfolgender Events in neuer Richtung bevor Richtungswechsel akzeptiert wird. Hoher = aggressivere Bounce-Filterung, aber trager bei echten Richtungswechseln |
| `IDLE_RESET_MS` | `200` | Nach dieser Pause (ms) wird Richtungsstatus zurueckgesetzt. Naechstes Event in beliebiger Richtung wird sofort akzeptiert |
| `ACCEL_MAX` | `3.0` | Maximaler Scroll-Multiplikator bei hoechster Geschwindigkeit. Zu hoch = uebersteuert, zu niedrig = schnelles Scrollen fuhlt sich traege an |
| `ACCEL_WINDOW_MS` | `100` | Events schneller als dies (ms) erhalten Beschleunigung. Daruber = 1.0x. Lineare Interpolation dazwischen |
| `HIRES_PER_STEP` | `120` | Standard v120-Konvention (nicht andern) |

Falls das Scrollen zu schnell/langsam ist: `ACCEL_MAX` und `ACCEL_WINDOW_MS` im Script anpassen, oder `ScrollFactor` in den Desktop-Einstellungen.

## Debugging

```bash
# Service-Logs anzeigen:
journalctl -u corsair-mouse-daemon -f

# Debug-Modus (zeigt PASS/HOLD/CONFIRM/accel fuer jedes Scroll-Event):
sudo systemctl stop corsair-mouse-daemon
nix-shell -p 'python3.withPackages(ps: [ps.evdev])' --run \
  "sudo python3 ~/nixos-config/scripts/corsair-mouse-daemon.py --debug-scroll"

# Events vom korrigierten virtuellen Gerat anzeigen:
nix-shell -p evtest --run "sudo evtest /dev/input/corsair-fixed"

# Rohe Events direkt von der Hardware (Daemon muss gestoppt sein):
nix-shell -p evtest --run "sudo evtest /dev/input/event8"

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
| `ckb-next` | Erkennt Darkstar uber Slipstream nicht (Issue ckb-next#1078) |
| iCUE (Windows VM) | Keine Scroll-Einstellungen fur Darkstar verfugbar |
| libinput Quirks (`AttrEventCode=-REL_WHEEL_HI_RES`) | Teilweise besser, aber Richtungsumkehr blieb |
| `evsieve` (Hi-Res blockieren) | Deutliche Verbesserung, aber kann Werte nicht skalieren |
| KDE `ScrollFactor` allein | Hilft bei Geschwindigkeit, nicht bei Richtungsumkehr |
| Separates virtuelles Keyboard fuer Remaps | Modifier funktionieren nicht Cross-Device unter Wayland |
| iCUE "Simuliere Gedrueckthalten" AN | Sendet sofort DOWN+UP, Hold funktioniert nicht |
| Zeitbasierte Debounce (DEBOUNCE_MS) | Unzuverlassig — Bounce-Timing variiert zu stark (40-80ms), echte Richtungswechsel werden falschlicherweise geblockt |
| Scroll-Werte durch 10 teilen (CORSAIR_SCROLL_DIVISOR) | Falsch — Werte sind bereits korrekt (±1/±120), Divisor hat Scrollen verschlechtert |
| Diskrete Beschleunigungsstufen (2x/3x Schwellenwerte) | Inkonsistent — kleine dt-Schwankungen verursachen Spruenge zwischen Stufen |

## Erkenntnisse aus evtest-Vergleich (2026-04-03)

Direktvergleich Corsair Darkstar vs Logitech USB Optical Mouse (`046d:c077`):

- Beide senden identische Scroll-Werte: `REL_WHEEL=±1, HI_RES=±120`
- Corsair hat Encoder-Bounce (einzelne Gegensignale 40-80ms nach echtem Event)
- Corsair verliert Encoder-Ticks bei sehr schnellem Scrollen (auch in evtest am Rohgerat sichtbar)
- USB-Polling bei beiden 1000Hz — kein Bottleneck
- Logitech hat keines dieser Probleme
