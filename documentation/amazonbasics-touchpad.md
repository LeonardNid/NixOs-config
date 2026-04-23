# AmazonBasics USB-Touchpad — Physischer Klick unter NixOS

**Stand: 2026-04-22 — PAUSE, offen. Kein NixOS-Deployment. Alles bisher
nur in `/tmp/*.py` Testscripten.**

## Problem

USB-Touchpad "AmazonBasics" (Telink-Chipset, `VID:PID = 248A:8278`) ist ein
**Clickpad** — die gesamte Oberfläche lässt sich mechanisch runterdrücken,
man hört und spürt einen Klick. Unter Linux kommt dieser physische Klick
aber **nicht** als Button-Event an. Unter Windows funktioniert er problemlos.

Aktuelle Workarounds in der niri-Config (`home/desktop-niri.nix`):

```
touchpad {
  tap            // tap-to-click als Ersatz für fehlenden phys. Klick
  natural-scroll
}
```

## Was die Untersuchung herausgefunden hat

### Die zwei Firmware-Modi

Das Touchpad hat zwei USB-HID-Interfaces:

- **iface 0** — HID Boot-Mouse (Standard-Maus-Report, 4 Byte: `btn, dx, dy, wheel`)
- **iface 1** — HID Touchpad / Digitizer (Windows Precision Touchpad, PTP)

Beide lassen sich per USB-Control-Transfer `SET_PROTOCOL`
(`bmRequestType=0x21, bRequest=0x0B`) zwischen **Boot** (wValue=0) und
**Report** (wValue=1) umschalten.

**Die Firmware hat einen globalen Mode-Switch** (empirisch bestätigt, siehe
Tests unten):

| Zustand | iface0 sendet | iface1 sendet |
|---|---|---|
| Beide in **BOOT** | Boot-Mouse-Reports inkl. Klick-Bit | nichts |
| Mindestens eins in **REPORT** | nichts | PTP Multi-Touch-Reports |

Das heißt: **entweder** Boot-Mouse (mit phys. Klick, ohne Multi-Touch)
**oder** PTP (mit Multi-Touch, ohne phys. Klick). Kein gleichzeitig.

### Warum Windows es kann

Windows bleibt im PTP-Mode, extrahiert aber das **Klick-Bit aus den
PTP-Reports selbst**. Das Linux-`hid-multitouch`-Modul scheint dieses
Bit entweder nicht zu parsen oder es als reinen Contact-Confidence-Wert
zu verwerfen. Nicht verifiziert — das ist die aktuelle Arbeitshypothese
(siehe "Nächste Schritte" unten).

### Default-Verhalten unter Linux

- Kernel bindet beim Einstecken `usbhid` an beide Interfaces.
- `usbhid` + `hid-multitouch` lassen iface1 im REPORT-Mode (PTP).
- iface0 bleibt default-mäßig in REPORT und ist damit **stumm** (globaler
  Mode-Switch auf PTP-Seite).
- Ergebnis: Multi-Touch/Scroll/Gesten/Tap funktionieren, phys. Klick nicht.

## Tests durchgeführt

Alle Test-Scripts liegen in `/tmp/*.py` und nutzen `pyusb`. Laufen mit:

```
nix-shell -p 'python3.withPackages (ps: [ ps.pyusb ])' --run 'sudo $(which python3) /tmp/<script>.py'
```

Wichtig: vor dem Claimen des Interfaces muss `usbhid` per sysfs unbound
werden (`/sys/bus/usb/drivers/usbhid/unbind` mit `1-3:1.0` bzw. `1-3:1.1`),
sonst `Resource busy` bei Control-Transfers.

### Test 1: `/tmp/reset-and-test.py`

USB-Reset, dann beide Interfaces in BOOT, beide lesen.
→ Ergebnis: iface0 sendet Boot-Mouse, iface1 stumm.

### Test 2: `/tmp/explore-boot-both.py`

30 Sekunden Capture, beide Interfaces in BOOT, User macht:
Klick, 1-Finger-Bewegung, 2-Finger-Scroll, 2-Finger-Tap, 3-Finger-Tap, Pinch.

**Ergebnis:**
- iface0: **305 Reports**, alle 4 Bytes, Format `[btn, dx, dy, wheel]`
  - Klick: `01 00 00 00` (16 Reports mit btn=0x01)
  - 1-Finger-Bewegung: `00 XX YY 00` (289 Reports ohne Klick)
  - **Wheel-Byte war durchgehend 0** — auch bei aktivem 2-Finger-Scroll
  - Nur BTN_LEFT — kein BTN_RIGHT (0x02), kein BTN_MIDDLE (0x04)
- iface1: **0 Reports** (boot-keyboard auf einem Touchpad macht keinen Sinn)

### Test 3: `/tmp/only-iface0.py`

iface0 in BOOT, iface1 **unangetastet** (bleibt REPORT, hid-multitouch bleibt
gebunden). User drückt 20 Sekunden mehrfach den Klick.

**Ergebnis: 0 Reports auf iface0.** → Bestätigt globalen Mode-Switch:
sobald iface1 in REPORT ist, ist iface0 stumm, unabhängig davon wer iface1
steuert.

### Test 4: `/tmp/iface1-boot.py`

Beide in BOOT, beide 15 Sekunden lesen, Samples drucken.
→ Gleiches Ergebnis wie Test 2 in kürzerer Form.

### Test 5: `/tmp/amazon-daemon.py` (funktionierender Prototyp)

Beide Interfaces unbinden → beide in BOOT-Mode → iface1 release (aber **nicht**
rebinden zu usbhid, weil der Rebind ein `SET_PROTOCOL=REPORT` auslöst und
damit iface0 global stumm schaltet) → Loop auf iface0, Parse `[btn,dx,dy,wheel]`,
Emit an uinput als `BTN_LEFT/RIGHT/MIDDLE` + `REL_X/Y/WHEEL`.

**Ergebnis: funktioniert.** Physischer Klick kommt als `BTN_LEFT` beim
Compositor an, Cursor-Bewegung funktioniert über den Daemon.

**Verlust gegenüber aktuellem Setup:**
- ❌ 2-Finger-Scroll (wheel-byte immer 0)
- ❌ Tap-to-Click (Firmware detektiert Taps nur im PTP-Mode)
- ❌ Right-click, Middle-click (Firmware sendet nur btn=0x01)
- ❌ Multi-Finger-Gesten (3-Finger-Swipe usw.)
- ❌ Pinch / Zoom

## Trade-off

| Option | Phys. Klick | Scroll | Tap | Gesten | Pinch |
|---|---|---|---|---|---|
| **Aktuell (REPORT / hid-multitouch)** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Daemon (beide BOOT)** | ✅ | ❌ | ❌ | ❌ | ❌ |

Boot-Mode-Daemon ist für dieses Touchpad **netto schlechter** als der aktuelle
Zustand. Nicht deployen.

## Status der NixOS-Config

### Was geändert wurde

`home/desktop-niri.nix` — touchpad-Block umgeschrieben (altes `click-method
"button-areas"` entfernt, weil sinnlos wenn kein Klick-Bit ankommt):

```
touchpad {
  // AmazonBasics Touchpad: Firmware sendet das Click-Bit nicht an den Host,
  // deshalb funktionieren "physische" Klicks nicht. Tap-to-Click ist der
  // einzige funktionierende Click-Weg (1 Finger = L, 2 Finger = R, 3 Finger = M).
  tap
  natural-scroll
  scroll-factor 1.0
  accel-speed 0.0
}
```

**Hinweis:** Der Kommentar stimmt inhaltlich **nicht mehr exakt**. Korrekter
wäre: "die Firmware schickt das Klick-Bit nur im Boot-Mode, nicht im
PTP-Mode den `hid-multitouch` nutzt." Sollte bei der nächsten
Bearbeitung angepasst werden — oder komplett entfernt werden wenn wir
das Problem anders lösen.

### Was temporär entfernt und nicht wieder eingefügt wurde

`hosts/leonardn/default.nix` — `hardware.uinput.enable = true;` und die
zugehörige udev-Rule wurden rausgenommen (war für den Daemon-Prototyp
gedacht, dann verworfen). Muss **nicht** wieder rein solange wir keinen
Daemon deployen.

### Was neu erstellt werden müsste (falls Daemon doch deployed wird)

1. `system/amazonbasics-touchpad-daemon.py` — basierend auf
   `/tmp/amazon-daemon.py`, aber mit Reconnect-Handling,
   sauberem Logging, systemd-Integration.
2. `system/amazonbasics-touchpad-daemon.nix` — analog zu
   `system/corsair-mouse-daemon.nix`: systemd-Unit, Dependency auf
   `hardware.uinput.enable`, udev-Rule für Restart bei Plug-In.
3. Import in `hosts/leonardn/default.nix` (nur Desktop).
4. `hardware.uinput.enable = true;` + uinput-udev-Rule wieder rein.

**Aktuell alles das nicht gemacht** — würden Multi-Touch opfern.

## Nächste Schritte (offen)

**Hypothese "dritter Weg"**: Im PTP-Mode bleiben (hid-multitouch macht
Multi-Touch wie bisher), **aber parallel** die rohen PTP-Reports von iface1
mitlesen (via hidraw oder indem wir `hid-multitouch` rauskicken und selbst
parsen) und das **Klick-Bit aus dem PTP-Report extrahieren**.

Der Windows-Treiber macht genau das. Wenn im PTP-Report tatsächlich ein
Button-Bit steht (was bei Windows Precision Touchpads üblich ist — Byte
mit Confidence/Tip-Switch/Button-Bits pro Contact), können wir:

- Multi-Touch via `hid-multitouch` **komplett behalten**
- Klicks via eigenen Daemon aus denselben PTP-Reports rausholen und als
  BTN_LEFT an uinput schicken

**Herausforderung**: Wenn wir iface1 von `hid-multitouch` unbinden um es
selbst zu lesen, verschwinden alle anderen Touch-Events aus dem System.
Also müsste unser Daemon dann den **gesamten** PTP-Parse übernehmen (nicht
nur Klick extrahieren) — oder wir nutzen hidraw parallel (iface1 bleibt
von `hid-multitouch` gebunden, wir lesen via `/dev/hidrawN` read-only mit).
Letzteres ist der sauberere Weg.

### Konkreter Plan wenn wir weitermachen

1. `lsusb -v` / `/dev/hidraw*` identifizieren — welche hidraw-Node ist iface1?
2. Kurzer Test: `cat /dev/hidrawN | xxd` während Klick + Gesten — sehen wir
   PTP-Reports? Haben die ein Button-Bit?
3. Falls ja: PTP-Descriptor parsen (`usbhid-dump` oder direkt aus dem
   Report-Descriptor) um genaue Bit-Position zu finden.
4. Mini-Daemon: `hidraw` read + uinput emit BTN_LEFT/RIGHT nur für den
   Button. Kein Cursor, kein Scroll — `hid-multitouch` macht den Rest.

Das wäre ein **klar besserer** Deal als der Boot-Mode-Daemon.

## Referenzen / Files

- Test-Scripts: `/tmp/explore-boot-both.py`, `/tmp/only-iface0.py`,
  `/tmp/iface1-boot.py`, `/tmp/reset-and-test.py`, `/tmp/amazon-daemon.py`
- Existierendes Daemon-Pattern: `system/corsair-mouse-daemon.nix`
  (+ `documentation/corsair-darkstar-maus.md`)
- niri-touchpad-Config: `home/desktop-niri.nix`
- Device: `lsusb` → `248a:8278 AmazonBasics ...`
- Kernel-Treiber: `usbhid` → `hid-multitouch` (iface1)
