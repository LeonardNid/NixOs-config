# Corsair Darkstar Wireless — Maus-Setup unter NixOS

## Zusammenfassung

Die Corsair Darkstar RGB Wireless hat unter Linux zwei Scroll-Probleme, beide
**unterhalb** der Linux-Software-Schicht:

1. **Firmware-seitige Encoder-Rate-Limitierung** bei schnellem Scrollen: die
   Maus verschluckt Ticks, bevor irgendein Linux-Code sie sieht.
2. **Wireless-Bounces** am 2,4-GHz-Slipstream-Link: vereinzelte Richtungsumkehr-
   Events ("Ghosts"), die nach echtem Scrollen auftauchen.

**Beide Probleme sind 2026-04-21 verifiziert und adressiert:**

- Problem 1 wurde durch **Firmware-Update via iCUE** (einmalig in der
  Windows-VM) deutlich entschärft. Die neue Firmware behandelt Encoder-Events
  weniger aggressiv. Scroll fühlt sich nun "akzeptabel" an — nicht
  Windows-perfekt, aber brauchbar. Settings sind on-board gespeichert und
  bleiben unter Linux aktiv, ohne dass iCUE laufen muss.
- Problem 2 wird vom Daemon abgefangen: `corsair-mouse-daemon-v2.py` filtert
  einzelne Ghost-Events aus dem Wireless-Stream, emittiert saubere Scroll-
  Events und remappt gleichzeitig die 8 Extra-Tasten.

Der Daemon erzeugt ein virtuelles Eingabegerät `CorsairFixed`, das unter
`/dev/input/corsair-fixed` als Symlink verfügbar ist. Dieses wird sowohl vom
Wayland-Compositor als Maus genutzt als auch von der Windows-VM per QEMU
`input-linux` passthrough.

## Hardware-Fakten

### USB-Topologie

Die Maus zeigt sich als zwei separate USB-Devices:

| Modus | Vendor:Product | Beschreibung |
|---|---|---|
| Wireless | `0x1B1C:0x1BDC` | Corsair Slipstream Receiver (Dongle) |
| Kabel | `0x1B1C:0x1BB2` | Darkstar direkt via USB-C |

Wenn der Dongle steckt und das Kabel gleichzeitig eingestöpselt ist, sind
**beide Pfade aktiv** — die Maus sendet dann über den aktuell gewählten
Pfad (von der Maus-Firmware gesteuert).

### HID-Interfaces

Der Slipstream-Receiver exponiert 6 HID-Interfaces:

| Interface | Usage | Rolle |
|---|---|---|
| 0 | Maus | Wheel-Data, Buttons, X/Y. **Einzige Quelle für Scroll-Events.** |
| 1, 2 | Vendor-specific (Usage Page 0xFF42) | iCUE-Command-Channel (Firmware-Update, Polling-Rate, Profile). Unter Linux ungenutzt. |
| 3, 5 | Keyboard | Extra-Tasten als `KEY_1`..`KEY_8` (iCUE-Mapping, siehe unten). |
| 4 | Zweite Maus (X/Y only) | Ungenutzt. |

**USB-Polling:** `bInterval=1` → 1000 Hz auf allen Endpoints. Der Receiver
ist **nicht** der Flaschenhals.

### Wheel-Encoder

- 8-bit signed Wheel (-127..127) im HID-Report, Kernel synthetisiert
  `REL_WHEEL_HI_RES = REL_WHEEL * 120`
- Pro physischer Rastung: normalerweise `REL_WHEEL=±1, REL_WHEEL_HI_RES=±120`
- Bei schneller Drehung bündelt die Firmware gelegentlich: `REL_WHEEL=±2`
- **Kein on-chip Resolution Multiplier, keine Hi-Res-Wheel-Usage** — der Wert
  kommt nur über den Kernel-synthesizer, nicht von der Maus.

## Die gemessenen Probleme

### Firmware-Rate-Limitierung (vor iCUE-Firmware-Update)

Kontrollierter Test mit `scripts/scroll-count-test.py` (User zählt gefühlte
Rastungen mit, Script zählt HID-Events):

| Scroll-Tempo | Gefühlt | HID-Events | Erfassung |
|---|---|---|---|
| Langsam (~1/s) | 20 | 20 | **100 %** |
| Game (~10/s) | ~50 | 29 | **~58 %** |
| Maximal | ~100 | 11 | **~11 %** |

Bei Maximal-Tempo lag der dt-Abstand zwischen HID-Events bei ~400 ms — obwohl
der User durchgehend drehte. Der Kernel hat diese Events nie gesehen, also
**kann kein Linux-seitiger Filter das ausgleichen.** Die Events existieren
schlicht nicht auf HID-Ebene.

Nach iCUE-Firmware-Update fühlt sich das Scrollen deutlich besser an; die
genaue Erfassungsrate wurde post-update nicht neu quantifiziert.

### Wireless-Bounces

Mit `scripts/bounce-test.py` (6 s schnelles Scrollen in eine Richtung):

| Modus | Bounce-Rate (Gegenrichtung-Events) |
|---|---|
| Wireless (Slipstream-Dongle) | **27 %** |
| Kabel | **11 %** |

Kabel halbiert Ghosts, eliminiert sie aber nicht. Die meisten Ghosts kommen
20–430 ms nach dem letzten echten Event. Das sind reine 2,4-GHz-Artefakte —
der Encoder selbst ist sauber (im Kabel-Modus verifiziert).

## Architektur

```
Corsair Darkstar Wireless (Hardware)
        │
        │ (2,4-GHz-Slipstream-Link ODER USB-C-Kabel)
        ▼
Host-USB
 ├── 0x1B1C:0x1BDC  Slipstream-Receiver  (6 HID-Interfaces)
 └── 0x1B1C:0x1BB2  Darkstar (Kabel)     (nur aktiv wenn Kabel steckt)
        │
        │ evdev (beide vom Daemon grabbed, exklusiv)
        ▼
corsair-mouse-daemon-v2.py (systemd-Service)
  1. Bounce-Filter:
       - Same-direction → sofort durchlassen
       - Einzelne Gegenrichtungs-Events → gepuffert (180 ms)
       - Zweites Gegenrichtungs-Event → echter Reversal, beide geflusht
       - Isolierter Ghost → verworfen
  2. Optionale Acceleration (ACCEL_MAX=3.0):
       - Dynamischer Faktor 1.0x–3.0x je nach dt zwischen Events
       - Nur auf Same-Direction-Pfad angewendet
  3. HI_RES-Emission:
       - Sowohl REL_WHEEL_HI_RES als auch legacy REL_WHEEL
       - Compositor kann Smooth-Scrolling nutzen
  4. Button-Remap (BUTTON_MAP dict):
       - KEY_1..KEY_8 von iCUE → Linux-Shortcuts / Modifier
        │
        ▼
CorsairFixed (UInput virtuelles Gerät)
  /dev/input/corsair-fixed  (via udev-Symlink, stabil trotz dynamischer event-Nr.)
        │
        ├─► Niri / KDE / Hyprland (Wayland-Compositor)
        │
        └─► Windows-VM (QEMU input-linux,evdev=/dev/input/corsair-fixed)
```

## iCUE-Konfiguration

iCUE läuft in einer Windows-VM. USB-Passthrough erfolgt per
`vm/usb-passthrough.sh` (siehe unten). Settings werden **on-board gespeichert**
und bleiben unter Linux aktiv, auch ohne laufendes iCUE.

### Button-Mapping (in iCUE setzen)

| Physische Taste | iCUE sendet | Daemon remappt zu |
|---|---|---|
| Vorne oben | KEY_1 | _(derzeit nicht remappt)_ |
| Vorne unten | KEY_2 | Super (LeftMeta) |
| Hinten oben | KEY_3 | Super+Right |
| Hinten unten | KEY_4 | Super+Left |
| DPI vorne | KEY_5 | Mute (Audio), dann Micmute |
| DPI hinten | KEY_6 | Micmute |
| Profil vorne | KEY_7 | _(derzeit nicht remappt)_ |
| Profil hinten | KEY_8 | _(derzeit nicht remappt)_ |

**Wichtig:** "Simuliere Gedrückthalten" in iCUE **muss AUS** sein, sonst
sendet die Firmware sofort KeyDown+KeyUp statt echtes Hold-Verhalten — damit
funktioniert z. B. das Super-Hold auf "Vorne unten" nicht.

Die `BUTTON_MAP` im Daemon wird direkt im Python-Script gepflegt
(`scripts/corsair-mouse-daemon-v2.py`). Action-Typen:

| Typ | Bedeutung |
|---|---|
| `int` | Einzelne Taste, z. B. `ecodes.KEY_LEFTMETA` |
| `[int, ...]` | Keyboard-Combo, Modifier zuerst |
| `[[...], [...]]` | Makro: Sequenz von Combos, jeweils DOWN+UP auf Button-Down |
| `None` | Taste komplett blockieren |

### iCUE-Wartung (Firmware-Flash, Polling-Rate, On-Board-Profile)

```bash
# Dongle an Windows-VM durchreichen (stoppt den Daemon automatisch)
./vm/usb-passthrough.sh attach wireless

# ...in Windows: iCUE öffnen, gewünschte Änderungen vornehmen,
#    explizit auf "Onboard Profile" speichern (nicht nur "Software Profile"),
#    bei Firmware-Update den Anweisungen folgen.

# Dongle zurück an den Host
./vm/usb-passthrough.sh detach wireless
sudo systemctl start corsair-mouse-daemon
```

**QEMU-Gotcha nach Daemon-Stop:** Wenn der Daemon gestoppt wird, während die
VM läuft, verliert QEMU seinen FD auf `/dev/input/corsair-fixed`. Nach
Daemon-Restart entsteht das Gerät zwar wieder, aber QEMU hält weiterhin den
toten FD — Symptom: Scroll-Lock-VM-Toggle reagiert nicht mehr. **Lösung:**
kompletter QEMU-Prozess-Neustart mit:

```bash
sudo virsh shutdown windows11
sudo virsh start windows11
```

`virsh reboot` reicht **nicht** — das ist nur ACPI-Reboot innerhalb von
Windows, der QEMU-Prozess bleibt derselbe.

## Beteiligte Dateien

| Datei | Zweck |
|---|---|
| `scripts/corsair-mouse-daemon-v2.py` | Python-Daemon: Bounce-Filter + Button-Remap |
| `scripts/corsair-mouse-daemon.py` | v1 (Legacy, nicht aktiv — aggressiverer DIR_CONFIRM-Filter) |
| `system/corsair-mouse-daemon.nix` | systemd-Service-Definition (zeigt auf v2) |
| `hosts/leonardn/default.nix` | Importiert das Nix-Modul |
| `vm/usb-passthrough.sh` | Dongle temporär an die VM durchreichen |
| `vm/windows11.xml` | QEMU `input-linux` passthrough für `/dev/input/corsair-fixed` |

## Diagnose-Skripte

Alle Skripte benötigen, dass der Daemon gestoppt ist (sie grabben die Devices
selbst). Nach dem Test den Daemon wieder starten.

```bash
sudo systemctl stop corsair-mouse-daemon
# ...test...
sudo systemctl start corsair-mouse-daemon
```

| Skript | Zweck |
|---|---|
| `scripts/scroll-count-test.py` | Live-Log jedes HID-Events mit Zähler + dt. Für Felt-vs-Measured-Vergleich. |
| `scripts/bounce-test.py` | 6 s DOWN + 6 s UP, berechnet Bounce-Rate. Erkennt wired und wireless automatisch (filtert nach Wheel-Usage im Report-Descriptor). |
| `scripts/double-scroll-test.py` | Loggt hidraw + Daemon-Output parallel mit Sequenz-IDs. Für Einzelfall-Debugging ("bei Event #247 hat's geflackert"). |
| `scripts/discover-all-buttons.py` | Druckt alle Button-Events; nützlich beim Anpassen der `BUTTON_MAP` nach Firmware-Update. |

Der Daemon selbst hat einen `--debug-scroll` Flag, der jedes Filter-Entscheidung
live auf stderr loggt (FIRST / PASS / BUFFER / CONFIRM / BOUNCE / IDLE / DROP):

```bash
sudo systemctl stop corsair-mouse-daemon
nix-shell -p 'python3.withPackages(ps: [ps.evdev])' --run \
  "sudo python3 ~/nixos-config/scripts/corsair-mouse-daemon-v2.py --debug-scroll"
```

## Tuning-Parameter (v2)

Im Script `scripts/corsair-mouse-daemon-v2.py`:

| Parameter | Default | Beschreibung |
|---|---|---|
| `PENDING_MAX_MS` | `180` | Wie lange ein einzelnes Gegenrichtungs-Event gepuffert wird, bevor es als Ghost verworfen wird. Muss unter typischer Reversal-Kadenz liegen. |
| `IDLE_RESET_MS` | `350` | Nach dieser Pause ohne Events wird der Richtungs-Status zurückgesetzt; der nächste Event passt in jede Richtung sofort durch. |
| `ACCEL_MAX` | `3.0` | Maximaler Scroll-Multiplier bei dt→0. Seit dem Firmware-Update evtl. zu aggressiv — wenn Scrolling "sprunghaft" wirkt, auf `1.0` setzen (Acceleration aus). |
| `ACCEL_WINDOW_MS` | `100` | Events mit dt unter diesem Wert erhalten Beschleunigung, linear skaliert. |
| `HIRES_PER_STEP` | `120` | Standard Hi-Res-Wheel-Konvention (nicht ändern). |

Legacy v1-Parameter (`DIR_CONFIRM`, `SPIKE_HOLD_MS`, `IDLE_RESET_MS=1000`)
existieren nur noch in `corsair-mouse-daemon.py` und sind nicht mehr aktiv.

## VM-Integration

Die VM `windows11` nutzt das virtuelle Gerät via QEMU `input-linux`:

```xml
<qemu:arg value="input-linux,id=mouse,evdev=/dev/input/corsair-fixed"/>
```

Damit gehen Maus-Events **automatisch** an die VM, sobald QEMU im VM-Mode ist
(gesteuert über Scroll-Lock auf dem Voyager-Keyboard via `vm-toggle-kbd.py`).
Kein USB-Passthrough der Maus nötig im Regelbetrieb.

Die `cgroup_device_acl` in der libvirtd-Konfiguration erlaubt Event-Nodes
event0–event299, damit die dynamische Event-Nummer von CorsairFixed
abgedeckt ist. Der udev-Regel-gesetzte Symlink macht den Pfad stabil:

```
KERNEL=="event*", ATTRS{name}=="CorsairFixed", SYMLINK+="input/corsair-fixed", GROUP="kvm", MODE="0666", TAG+="uaccess"
```

Für iCUE-Maintenance (und nur dann) wird der **Dongle** als echtes
USB-Device durchgereicht — siehe "iCUE-Wartung" oben.

## Historisches: Was nicht funktioniert hat

| Ansatz | Ergebnis |
|---|---|
| `ckb-next` | Erkennt Darkstar via Slipstream nicht (ckb-next#1078). |
| libinput-Quirks (`AttrEventCode=-REL_WHEEL_HI_RES`) | Teilweise besser, aber Richtungsumkehr blieb. |
| `evsieve` (Hi-Res blockieren) | Deutlich besser, aber kann Werte nicht skalieren. |
| KDE `ScrollFactor` allein | Hilft bei Geschwindigkeit, nicht bei Richtungsumkehr. |
| Separates virtuelles Keyboard für Remaps | Modifier funktionieren nicht cross-device unter Wayland. |
| iCUE "Simuliere Gedrückthalten" AN | Sendet sofort DOWN+UP, Hold funktioniert nicht. |
| Zeitbasierter Debounce (Linux-seitig) | Unzuverlässig — Bounce-Timing variiert zu stark (20–430 ms), echte Reversals werden geblockt. |
| v1-Filter (`DIR_CONFIRM=2`, `IDLE_RESET_MS=1000`) | Ersetzt durch v2 (Single-Bounce-Absorber, kürzerer Idle-Reset). |
| Scroll-Werte skalieren (CORSAIR_SCROLL_DIVISOR) | Falsch — Werte sind bereits ±1/±120, Divisor verschlechtert das Scrollen. |
| Hidraw-basierter Daemon | Unnötig — iface 0 ist bit-identisch zu evdev für Wheel-Daten. |
| Niri als Ursache verdächtigt | Widerlegt — das Bottleneck liegt vor dem Daemon (auf Firmware-Ebene). |
| **iCUE → keine Scroll-Einstellungen verfügbar** | **Widerlegt 2026-04-21** — Firmware-Update via iCUE hat das Scroll-Problem deutlich entschärft. |

## Wenn das Scroll-Problem zurückkommt

1. Zuerst: Firmware in iCUE neu flashen (Settings sind sonst flüchtig, falls
   ein Reset passiert ist).
2. Falls Firmware-Flash nicht hilft: iCUE ff42-Protokoll reverse-engineeren.
   Mit `usbmon` + Wireshark in der Windows-VM den Traffic während eines
   Polling-Rate-Change oder Firmware-Update aufzeichnen (iface 1 oder 2,
   Usage Page 0xFF42). Pakete replay beim Daemon-Start. Mehrere Stunden
   Aufwand, bisher nicht nötig gewesen.
3. `ckb-next` / `OpenRGB` prüfen, ob dort inzwischen Darkstar-Support
   existiert, den man übernehmen könnte.
