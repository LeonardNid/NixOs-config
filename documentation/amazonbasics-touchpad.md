# AmazonBasics USB-Touchpad — Physischer Klick unter NixOS

**Stand: 2026-04-23 — Hotspot-Daemon deployed, physischer Button final als
unmöglich verworfen (ohne Windows-Reverse-Engineering).**

## Problem

USB-Touchpad "AmazonBasics" (Telink-Chipset, `VID:PID = 248A:8278`) ist ein
**Clickpad** — die gesamte Oberfläche lässt sich mechanisch runterdrücken,
man hört und spürt einen Klick. Unter Linux kommt dieser physische Klick
aber **nicht** als Button-Event an. Unter Windows funktioniert er problemlos.

## Was deployed ist

### Hotspot-Daemon (aktiv)

- `scripts/amazonbasics-touchpad-daemon.py` — Python-Daemon
- `system/amazonbasics-touchpad-daemon.nix` — systemd-Unit
- Importiert in `hosts/leonardn/default.nix`

**Funktionsweise:** Das Touchpad-evdev wird exklusiv gegrabbed (`EVIOCGRAB`)
und 1:1 auf ein virtuelles uinput-Touchpad gespiegelt — libinput sieht das
virtuelle Gerät und behandelt es wie das Original. Einziger Unterschied:
**Ein-Finger-Taps, die innerhalb eines definierten Hotspot-Rechtecks
starten, werden geschluckt** (kein BTN_LEFT, kein Cursor-Move) und durch
einen Tastatur-Combo auf einem separaten virtuellen Keyboard-Device
ersetzt.

**Aktueller Hotspot:** Oben links 20% × 20% der Padfläche → `Super+O`
(niri `toggle-overview`).

Tap-Klassifizierung: Finger muss innerhalb `TAP_MAX_MS=180` wieder weg sein
und sich nie weiter als `TAP_MAX_DIST=30` Einheiten (~2.3 mm) bewegt haben.
Sonst Pass-through als normale Geste. Multi-Finger im Hotspot → immer
pass-through.

### niri-Touchpad-Config (`home/desktop-niri.nix`)

```
touchpad {
  tap
  natural-scroll
  scroll-factor 1.0
  accel-speed 0.0
}
```

Tap-to-Click bleibt der primäre Ersatz für den fehlenden physischen Klick.
Der Hotspot-Daemon ist **zusätzlich** — er deaktiviert Tap in seinem
Bereich und mapped ihn stattdessen auf die Tastenkombi.

## Was die Untersuchung endgültig festgestellt hat

### Die zwei Firmware-Modi (globaler Mode-Switch)

Das Touchpad hat zwei USB-HID-Interfaces:

- **iface 0** — HID Boot-Mouse (Standard-Maus-Report, 4 Byte: `btn, dx, dy, wheel`)
- **iface 1** — HID Touchpad / Digitizer (Windows Precision Touchpad, PTP)

Die Firmware hat einen **globalen Mode-Switch**:

| Zustand | iface0 sendet | iface1 sendet |
|---|---|---|
| Beide in **BOOT** | Boot-Mouse-Reports inkl. Klick-Bit | nichts |
| Mindestens eins in **REPORT** | nichts | PTP Multi-Touch-Reports |

**Entweder** Boot-Mouse (mit phys. Klick, ohne Multi-Touch) **oder** PTP
(mit Multi-Touch, ohne phys. Klick). Nicht gleichzeitig.

### Das PTP-Button-Bit existiert, wird aber nie gesetzt

Der HID-Report-Descriptor von iface1 (gelesen aus
`/sys/bus/hid/devices/0003:248A:8278.0007/report_descriptor`) deklariert
am Ende jedes PTP-Reports ein **Button-1-Feld**:

```
Report ID 0x04, 30 Byte:
  Byte 0:      Report ID
  Bytes 1-25:  5× Finger-Struct (Confidence/TipSwitch/ContactID + X + Y)
  Bytes 26-27: Scan Time (16-bit LE)
  Byte 28:     Contact Count
  Byte 29:     Button 1 (Bit 0) + 7 Bit Padding  ← soll das Klick-Bit sein
```

**Empirischer Test** (`/tmp/hidraw-button2.py`, 15s, 1407 PTP-Reports
durchgängig mitgelesen auf `/dev/hidraw6`, Finger permanent aufliegend,
Druckphasen variiert):

- Phase "locker aufliegen":  byte29 = 0x00
- Phase "mechanisch drücken": byte29 = 0x00
- Phase "loslassen":           byte29 = 0x00

Byte 29 bleibt **in 100% der Reports 0x00**, unabhängig vom mechanischen
Drücken. Die Firmware deklariert das Button-Bit im Descriptor, setzt es
aber niemals. Das ist kein Linux-Parsing-Artefakt — wir lesen die rohen
USB-Reports.

### Warum Windows es trotzdem kann

Unbekannt. Mögliche Erklärungen:

1. Windows schickt eine proprietäre SET_FEATURE/SET_REPORT-Sequenz die die
   Button-Reports freischaltet (bei manchen Telink-/Chinesen-Chipsets
   üblich).
2. Windows nutzt einen anderen Report (Feature-Report oder eine andere
   Report-ID) die bei uns nicht auftaucht.
3. Windows setzt ein Bit in einem Konfigurations-Register via Control-Transfer.

Zur Klärung wäre eine Windows-USB-Capture (Wireshark + usbmon in VM)
nötig. **Nicht gemacht**.

## Historische Tests (zur Nachvollziehbarkeit)

Alle Test-Scripts liegen in `/tmp/*.py`.

| Test | Ergebnis |
|---|---|
| `/tmp/reset-and-test.py` — beide iface in BOOT | iface0 sendet Boot-Mouse inkl. Klick, iface1 stumm |
| `/tmp/explore-boot-both.py` — 30s Capture beider iface in BOOT | 305 Mouse-Reports iface0, 0 auf iface1. Wheel-Byte **immer 0** (auch bei 2-Finger-Scroll), nur BTN_LEFT (kein Right/Middle) |
| `/tmp/only-iface0.py` — iface0 BOOT, iface1 unangetastet (REPORT) | 0 Reports auf iface0 — bestätigt globalen Mode-Switch |
| `/tmp/amazon-daemon.py` — Boot-Mode-Daemon Prototyp | Funktioniert: BTN_LEFT + Cursor kommen. **Verliert** Scroll, Tap, Right/Middle, Gesten, Pinch → netto schlechter |
| `/tmp/iface0-mouse-probe.py` — iface0 in REPORT lesen während iface1 PTP | 0 Reports (global mode switch) |
| `/tmp/hidraw-button2.py` — PTP-Byte-29 tracken unter wechselndem Druck | byte29 bleibt 0x00, 100% |

## Trade-off-Tabelle (endgültig)

| Option | Phys. Klick | Scroll | Tap | Gesten | Pinch | Hotspot |
|---|---|---|---|---|---|---|
| Default (hid-multitouch) | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Boot-Mode-Daemon | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Hotspot-Daemon (deployed)** | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PTP-byte29-Parsing | nicht möglich (Firmware setzt Bit nie) |

## Offene Optionen (nicht deployed)

### Windows-Reverse-Engineering

Der einzig verbleibende Weg zum physischen Button. Wäre:

1. Windows in VM mit USB-Passthrough des Touchpads.
2. `usbmon` oder Wireshark `usbpcap` beim ersten Einstecken mitschneiden.
3. Sequenz der Control-Transfers + Feature-Reports analysieren.
4. Reproduzieren auf Linux (pyusb Control-Transfer vor `hid-multitouch`-Bind).
5. Erneut `/tmp/hidraw-button2.py` ausführen — ändert sich byte 29 jetzt?

Unsicher ob erfolgreich. Aufwand: mehrere Stunden + VM mit USB-Passthrough
aufsetzen.

### Hotspot-Erweiterungen

Das Daemon-Konstrukt ist generisch — zusätzliche Hotspots sind trivial:

- Mehrere Rechtecke mit unterschiedlichen Key-Combos
- Randbereiche (z.B. rechte Kante für Scroll-Gesten-Override)
- Drag-Erkennung (Tap+Hold → Keyboard modifier)

Alles in `scripts/amazonbasics-touchpad-daemon.py`, keine Config-Änderungen
außerhalb des Python-Files nötig (danach `rebuild`).

## Referenzen / Files

- **Produktion:** `scripts/amazonbasics-touchpad-daemon.py`,
  `system/amazonbasics-touchpad-daemon.nix`,
  Import in `hosts/leonardn/default.nix`
- **niri-touchpad-Config:** `home/desktop-niri.nix`
- **Verwandtes Daemon-Pattern:** `system/corsair-mouse-daemon.nix`
- **Test-Scripts:** `/tmp/explore-boot-both.py`, `/tmp/only-iface0.py`,
  `/tmp/iface1-boot.py`, `/tmp/reset-and-test.py`, `/tmp/amazon-daemon.py`,
  `/tmp/hidraw-button.py`, `/tmp/hidraw-button2.py`, `/tmp/hidraw-diff.py`,
  `/tmp/hidraw-click-probe.py`, `/tmp/iface0-mouse-probe.py`
- **Device:** `lsusb` → `248a:8278 AmazonBasics ...`
- **Kernel-Treiber:** `usbhid` → `hid-multitouch` (iface1)
- **Touchpad-Geometrie:** X 0-1973, Y 0-1458, Auflösung 13 Einheiten/mm
  (~15.2 cm × 11.2 cm)
- **HID-Devices (Enumeration ändert sich je Reconnect):**
  - iface0 evdev: per Name "Telink amazonbasics_touchpad Mouse"
  - iface1 evdev: per Name "Telink amazonbasics_touchpad Touchpad"
  - iface0/iface1 hidraw: über `/sys/class/hidraw/*/device` → `0003:248A:8278.xxxx`
