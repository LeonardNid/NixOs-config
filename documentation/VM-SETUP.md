# Windows 11 Gaming VM — Vollständige Systemdokumentation

Erstellt: 2026-03-26

## Übersicht

Windows 11 VM mit GPU-Passthrough (NVIDIA RTX 3080) auf NixOS Linux zum Gaming.
Das Bild der VM wird über Looking Glass auf dem Linux-Desktop angezeigt, sodass man
nicht zwischen Monitor-Eingängen wechseln muss.

## Hardware

| Komponente | Details |
|---|---|
| CPU | Intel Core i5-14600K (6P+8E Kerne, 20 Threads) |
| RAM | 32 GB (16 GB für VM, 16 GB für Linux) |
| GPU (VM) | NVIDIA GeForce RTX 3080 (VFIO Passthrough) |
| GPU (Linux) | Intel UHD 770 (integriert, RPL-S) |
| Monitor | 2560x1440, HDMI → Intel iGPU (Linux), DP → NVIDIA (VM) |
| Tastatur | ZSA Voyager (USB, 2 Interfaces: Boot-KBD + NKRO via if03) |
| Maus (kabellos) | Corsair SLIPSTREAM Wireless USB Receiver (1b1c:1bb2) |
| Maus (kabelgebunden) | Corsair DARKSTAR (1b1c:1bdc) |
| Controller | Sony DualSense PS5 (054c:0ce6, USB Passthrough) |
| Keypad | Azeron Keypad (16d0:12f7, USB Passthrough) |
| SSD (Linux) | Samsung SSD 850 EVO 500GB (/dev/sda) |
| HDD (VM) | WD Black 1TB (/dev/sdb, NTFS, Block-Passthrough als vdb) |
| NVMe (VM) | Kingston KC3000 2TB (/dev/nvme0n1, NTFS, Block-Passthrough als vdc) |

## Software

- **Host OS**: NixOS (Flake-basiert, KDE Plasma 6, Wayland)
- **Guest OS**: Windows 11 Pro (Build 26200)
- **Hypervisor**: libvirt + QEMU (q35-9.2 Maschine)
- **Display**: Looking Glass B7 (IVSHMEM/KVMFR)
- **Audio**: Scream 4.0 (UDP Multicast über virbr0)

## Dateien & Konfiguration

### Wichtige Dateipfade

| Datei | Beschreibung |
|---|---|
| `/etc/nixos/configuration.nix` | NixOS Hauptkonfiguration |
| `/etc/nixos/home.nix` | Home Manager Konfiguration |
| `/home/leonardn/windows11.xml` | libvirt VM-Definition |
| `/var/lib/libvirt/images/win11.qcow2` | Windows VM-Disk |
| `/dev/kvmfr0` | KVMFR Shared Memory Device (128 MiB) |

### Windows-seitige Dateien

| Datei | Beschreibung |
|---|---|
| `C:\Program Files\Looking Glass (host)\looking-glass-host.exe` | LG Host Application |
| `C:\Program Files\Looking Glass (host)\looking-glass-host.ini` | LG Host Konfiguration (optional) |
| `C:\ProgramData\Looking Glass (host)\looking-glass-host.txt` | LG Host Log |

---

## 1. GPU Passthrough (VFIO)

### Kernel-Parameter (`configuration.nix`)

```nix
boot.kernelParams = [
  "intel_iommu=on,sm_on"
  "iommu=pt"
  "vfio-pci.ids=10de:2206,10de:1aef"  # RTX 3080 GPU + Audio
  "random.trust_cpu=on"
];
boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];
```

- `intel_iommu=on,sm_on`: Aktiviert Intel IOMMU mit Scalable Mode
- `iommu=pt`: Passthrough-Modus (bessere Performance)
- `vfio-pci.ids`: Bindet die NVIDIA GPU (10de:2206) und deren HDMI-Audio (10de:1aef) an den VFIO-Treiber beim Boot
- `nouveau`/`nvidiafb` werden blockiert damit sie die GPU nicht vor VFIO beanspruchen

### VM XML (GPU-Abschnitt)

```xml
<!-- RTX 3080 GPU (PCI 01:00.0) -->
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
  </source>
  <rom bar="on"/>
</hostdev>

<!-- RTX 3080 HDMI Audio (PCI 01:00.1) -->
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
  </source>
</hostdev>
```

### Anti-Detection (damit NVIDIA-Treiber in VM funktioniert)

```xml
<hyperv mode="custom">
  <vendor_id state="on" value="randomid"/>
</hyperv>
<kvm>
  <hidden state="on"/>
</kvm>
```

---

## 2. Looking Glass (Bildschirmübertragung)

### Wie es funktioniert

1. Die NVIDIA GPU rendert den Windows-Desktop
2. Der **Looking Glass Host** (Windows-App) captured den Desktop via Desktop Duplication (D12/DXGI)
3. Die Frames werden in **IVSHMEM Shared Memory** geschrieben (128 MiB, `/dev/kvmfr0`)
4. Der **Looking Glass Client** (Linux-App) liest die Frames aus dem Shared Memory und zeigt sie an

### KRITISCH: IVSHMEM muss über qemu:commandline konfiguriert werden

Das `<shmem>`-Element in libvirt XML erstellt einen eigenen Shared-Memory-Bereich unter
`/dev/shm/looking-glass`. Der KVMFR Kernel-Modul erstellt aber `/dev/kvmfr0` mit eigenem Speicher.
**Diese sind NICHT derselbe Speicher!**

Wenn man `<shmem>` nutzt, schreibt der Host nach `/dev/shm/looking-glass` und der Client liest
von `/dev/kvmfr0` — sie reden aneinander vorbei und der Client sagt "host seems to not be running".

**Lösung**: IVSHMEM via `qemu:commandline` konfigurieren und explizit `/dev/kvmfr0` als
Memory-Backend angeben:

```xml
<qemu:commandline>
  <qemu:arg value="-device"/>
  <qemu:arg value="{'driver':'ivshmem-plain','id':'shmem0','memdev':'looking-glass'}"/>
  <qemu:arg value="-object"/>
  <qemu:arg value="{'qom-type':'memory-backend-file','id':'looking-glass','mem-path':'/dev/kvmfr0','size':134217728,'share':true}"/>
</qemu:commandline>
```

128 MiB = 134217728 Bytes. Dieser Wert muss mit `static_size_mb` des KVMFR-Moduls übereinstimmen.

### KVMFR Kernel-Modul (`configuration.nix`)

```nix
boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
boot.kernelModules = [ "kvmfr" ];
boot.extraModprobeConfig = ''
  options kvmfr static_size_mb=128
'';
```

### cgroup_device_acl

QEMU braucht Zugriff auf `/dev/kvmfr0`. Ohne Eintrag in `cgroup_device_acl` bekommt man
"Operation not permitted" beim VM-Start. Nach Änderung muss `libvirtd` neu gestartet werden:
`sudo systemctl restart libvirtd`

```nix
qemu.verbatimConfig = ''
  cgroup_device_acl = [
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/userfaultfd",
    "/dev/kvmfr0",
    ...event devices...
  ]
'';
```

### udev-Regel für /dev/kvmfr0

```nix
SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
```

**Wichtig**: Kein `OWNER="leonardn"` verwenden — udev kann Benutzernamen beim Boot nicht auflösen
(`Failed to resolve user`). Stattdessen nur `GROUP="kvm"` setzen. Der User `leonardn` ist Mitglied
der `kvm`-Gruppe und hat dadurch Zugriff.

### VGA Device (Pflicht laut LG-Doku)

```xml
<video>
  <model type="vga"/>
</video>
```

Dies erstellt einen "Microsoft Basic Display Adapter" in Windows. Er wird für die SPICE-Fallback-Anzeige benötigt. Ohne dieses Device gibt es kein SPICE-Display. **NICHT entfernen!**

### Virtual Display Driver (VDD)

In Windows muss der **Virtual Display Driver** installiert sein (von https://github.com/VirtualDrivers/Virtual-Display-Driver).
Ohne VDD kann die DXGI/D12-Factory nicht erstellt werden und der Host crashed sofort mit `0x887a0001`.

VDD erstellt einen separaten virtuellen Grafik-Adapter. Dieser wird NICHT von Looking Glass captured
(LG captured nur vom NVIDIA-Adapter), aber er ist notwendig damit die DXGI-Runtime funktioniert.

### NVIDIA Custom Resolution

Die NVIDIA GPU ist per DP an einen 1080p-Monitor angeschlossen. Der Linux-Monitor ist 2560x1440.
Damit Looking Glass in nativer 1440p-Auflösung captured, muss in Windows eine benutzerdefinierte
Auflösung erstellt werden:

1. NVIDIA Systemsteuerung → Anzeige → Auflösung ändern → Anpassen
2. "Auflösungen aktivieren, die nicht von der Anzeige angeboten werden"
3. Benutzerdefinierte Auflösung: **2560x1440 @ 60Hz**
4. Als aktive Auflösung setzen

### Client starten

```bash
looking-glass-client -f /dev/kvmfr0 win:size=2560x1440 win:dontUpscale=on spice:enable=no
```

- `-f /dev/kvmfr0`: KVMFR Device
- `win:size=2560x1440`: Fenstergröße auf 1440p setzen
- `win:dontUpscale=on`: Kein Upscaling (verhindert pixeliges Bild)
- `spice:enable=no`: SPICE-Fallback deaktivieren (nur IVSHMEM-Bild nutzen)

### Host (Windows)

Der Looking Glass Host startet als reguläre Anwendung (NICHT als Service — Services laufen in
Session 0 ohne DXGI-Zugriff). Er captured über das D12-Backend (DirectX 12 Desktop Duplication)
von der NVIDIA GPU (DISPLAY2).

Der Host kann als Autostart-Programm eingerichtet werden.

---

## 3. Eingabegeräte (evdev Passthrough)

### Wie es funktioniert

Die Tastatur und Maus werden über QEMU `input-linux` an die VM durchgereicht. Ein eigener **VM Toggle Keyboard Forwarding Daemon** (`scripts/vm-toggle-kbd.py`) verwaltet die ZSA Voyager Tastatur, kombiniert alle USB-Endpunkte in ein virtuelles Gerät (`/dev/input/virtual-voyager`) und steuert den Toggle-Mechanismus zwischen Linux-Host und Windows-VM. 
Mit der **Scroll Lock**-Taste kann jederzeit nahtlos zwischen Linux und VM gewechselt werden, ohne dass KDE-Shortcuts benötigt werden.

### ZSA Voyager Tastatur und Toggle-Daemon

Da die Voyager mehrere Interfaces besitzt und QEMUs interner `grab-toggle` Mechanismus Limits hat (Slaves werden nur von Master-Geräten freigegeben), übernimmt der Daemon die Steuerung:
- **Im VM-Modus**: Eingaben gehen an `virtual-voyager` (von QEMU ohne eigenen `grab-toggle` gegriffen).
- **Beim Toggle**: Der Daemon erkennt `ScrollLock`, gibt die physischen Tastaturen frei (für Linux) und drückt virtuell `ScrollLock` auf einem dedizierten `vm-toggle-kbd` Gerät, das QEMU dazu zwingt, seine Cascade loszulassen (wodurch die Maus freigegeben wird).
- **Beim Start/Stop**: Über ein FIFO (`/tmp/vm-toggle-kbd.fifo`) wird der Daemon durch das `vm`-Script beim Booten und Herunterfahren exakt mit QEMU synchronisiert (`init_linux_after_qemu_start` und `force_linux`).

```xml
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse,evdev=/dev/input/corsair-fixed"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse2,evdev=/dev/input/logitech-fixed"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=kbd0,evdev=/dev/input/virtual-voyager,grab_all=on,repeat=on"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=vm-toggle,evdev=/dev/input/vm-toggle-kbd,grab_all=on,grab-toggle=scrolllock"/>
```

**Reihenfolge ist wichtig**: Alle Mäuse (Slaves, kein `grab_all`) müssen ZUERST definiert werden, danach die Tastaturen (`virtual-voyager`, `vm-toggle`). Nur so erreicht die Ungrab-Cascade von `vm-toggle` rückwärts alle Slaves.

---

### Mäuse via evdev-Daemon: Architektur

Jede Maus, die per Scroll-Lock umschalten soll, läuft durch einen **evdev-Daemon**:

```
Physische Maus (USB)
    └─ Daemon (python3 + evdev)
           ├─ EVIOCGRAB auf physisches Gerät  (Linux-Desktop sieht keine direkten Events)
           └─ Schreibt Events auf UInput-Virtualgerät ("XyzFixed")
                  └─ udev-Symlink: /dev/input/xyz-fixed → /dev/input/eventN
                         └─ QEMU input-linux: evdev=/dev/input/xyz-fixed  →  VM
```

**Warum der Umweg über einen Daemon statt direktes evdev-Passthrough?**

- Die Event-Nummer (`eventN`) ändert sich je nach Boot-Reihenfolge und Steck-Reihenfolge. Ein Symlink auf einen festen Namen ist stabiler als ein hardcodierter Pfad.
- Für die Corsair ist ein Scroll-Fix (Encoder-Bounce-Korrektur + Beschleunigung) notwendig, der im Daemon läuft.
- Der Daemon kann Button-Remapping, Makros und andere Korrekturen übernehmen, die QEMU nicht kann.

**Dummy-Modus wenn Gerät nicht angeschlossen**

Wenn die physische Maus beim Daemon-Start nicht gefunden wird, erstellt der Daemon trotzdem das virtuelle Gerät mit demselben Namen — aber als leeres Dummy-Gerät ohne Events:

- `/dev/input/xyz-fixed` existiert immer → QEMU-Start schlägt nicht fehl
- Der Daemon prüft alle 3 Sekunden ob die physische Maus erschienen ist
- Sobald sie eingesteckt wird: Daemon beendet sich mit Exit-Code 1 → systemd startet neu → volles Forwarding

**Wichtig: Eigene UInput-Geräte aus der Suche ausschließen**

Ohne Schutz findet der Daemon beim Polling sein eigenes Dummy-Gerät (gleiche Vendor:Product-IDs) und bootet endlos neu. Der Fix: UInput-Geräte haben `phys = "py-evdev-uinput"`, physische USB-Geräte haben z.B. `phys = "usb-0000:00:14.0-12/input0"`. Daher in jedem Daemon:

```python
if "uinput" in (dev.phys or ""):
    dev.close()
    continue
```

---

### Neue Maus hinzufügen — Schritt-für-Schritt

#### Schritt 1: Vendor:Product-ID ermitteln

Maus einstecken, dann:

```bash
cat /proc/bus/input/devices | grep -A 8 -i "<gerätename>"
```

Im Sysfs-Pfad steht Vendor und Product im Format `VVVV:PPPP`:

```
S: Sysfs=/devices/.../0003:046D:C08F.001A/input/input59
                              ^^^^  ^^^^
                           Vendor  Product
```

→ Vendor: `046d`, Product: `c08f` (Kleinbuchstaben für udev-Regeln)

Alternativ (wenn `usbutils` verfügbar): `lsusb | grep -i <name>`

#### Schritt 2: Daemon-Skript erstellen

`scripts/<name>-mouse-daemon.py` anlegen. Als Vorlage:

- **Einfache Maus** (kein Scroll-Fix): `scripts/logitech-mouse-daemon.py` kopieren und anpassen
- **Maus mit Encoder-Bounce-Problemen**: `scripts/corsair-mouse-daemon-v2.py` kopieren und anpassen

Die drei Stellen die immer angepasst werden müssen:

```python
VENDOR_<NAME>  = 0x046D   # Vendor-ID (hex)
PRODUCT_<NAME> = 0xC08F   # Product-ID (hex)

# Im UInput-Konstruktor:
ui = UInput(caps, name="<Name>Fixed", vendor=VENDOR_<NAME>, product=PRODUCT_<NAME>)
#                       ^^^^^^^^^^^
#                   Dieser Name erscheint in udev (ATTRS{name})
```

In `find_<name>_devices()` Vendor/Product-Filter und Geräteerkennung (REL_X für Maus, EV_LED für Keyboard-Interface) anpassen. Das `"uinput" in (dev.phys or "")` Skip **immer drinlassen**.

#### Schritt 3: Systemd-Service anlegen

`system/<name>-mouse-daemon.nix`:

```nix
{ pkgs, ... }:
{
  systemd.services.<name>-mouse-daemon = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "<Gerätename> Mouse Daemon (evdev passthrough)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/<name>-mouse-daemon.py}";
    };
  };
}
```

#### Schritt 4: udev-Regeln ergänzen

In `vm/gpu-passthrough.nix`, im `services.udev.extraRules`-Block **zwei Zeilen** hinzufügen:

```nix
# 1. Physisches Gerät: Zugriffsrechte (damit der Daemon es grabben kann)
SUBSYSTEM=="input", ATTRS{idVendor}=="<vendor>", ATTRS{idProduct}=="<product>", GROUP="kvm", MODE="0660"
# 2. Virtuelles Gerät: stabiler Symlink für QEMU
KERNEL=="event*", ATTRS{name}=="<Name>Fixed", SYMLINK+="input/<name>-fixed", GROUP="kvm", MODE="0666", TAG+="uaccess"
```

Regeln:
- Vendor/Product in **Kleinbuchstaben** (udev-Konvention)
- `ATTRS{name}` muss exakt mit dem `name=`-Parameter im UInput-Konstruktor übereinstimmen
- `MODE="0666"` beim virtuellen Gerät damit QEMU (root) es grabben kann
- Die Reihenfolge in der Datei ist egal, aber der Übersicht halber bei den anderen Corsair/Logitech-Regeln einfügen

#### Schritt 5: QEMU XML erweitern

In `vm/windows11.xml`, den neuen Slave **vor** den Keyboard-Einträgen einfügen:

```xml
<!-- Mäuse (Slaves): alle vor den Tastaturen -->
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse,evdev=/dev/input/corsair-fixed"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse2,evdev=/dev/input/logitech-fixed"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse3,evdev=/dev/input/<name>-fixed"/>
<!-- Tastaturen (Masters): immer nach den Mäusen -->
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=kbd0,evdev=/dev/input/virtual-voyager,grab_all=on,repeat=on"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=vm-toggle,evdev=/dev/input/vm-toggle-kbd,grab_all=on,grab-toggle=scrolllock"/>
```

IDs (`mouse`, `mouse2`, `mouse3`, ...) müssen eindeutig sein. Mäuse bekommen **kein** `grab_all` — das ist nur für die Tastaturen nötig, die die Cascade auslösen.

#### Schritt 6: Modul in Host importieren

In `hosts/leonardn/default.nix` hinzufügen:

```nix
../../system/<name>-mouse-daemon.nix
```

#### Schritt 7: Rebuild + VM neu definieren

```bash
rebuild "<beschreibung>"
```

Danach **zwingend** die VM-Definition in libvirt aktualisieren. libvirt liest `windows11.xml` **nicht automatisch** — es hält eine eigene Kopie der VM-Definition. Ohne diesen Schritt startet die VM mit der alten XML und das neue Gerät fehlt im QEMU-Commandline:

```bash
vm stop   # falls VM läuft
sudo virsh define /home/leonardn/nixos-config/vm/windows11.xml
vm start
```

Kein `virsh undefine` nötig (und auch nicht gewollt — das würde die NVRAM-Datei löschen und Windows verliert seine UEFI-Einstellungen).

#### Schritt 8: Prüfen

```bash
# Symlink vorhanden und zeigt auf ein existierendes Gerät?
ls -la /dev/input/<name>-fixed

# Daemon läuft stabil (kein Restart-Loop)?
systemctl status <name>-mouse-daemon

# QEMU hat das Gerät geöffnet (nach vm start)?
QPID=$(pgrep -f "qemu-system-x86_64" | head -1)
sudo cat /proc/$QPID/cmdline | tr '\0' '\n' | grep input-linux
```

Die letzte Prüfung muss alle konfigurierten `input-linux`-Einträge zeigen (mouse, mouse2, ..., kbd0, vm-toggle). Fehlt ein Eintrag, hat QEMU das Gerät nicht geöffnet — häufigste Ursache: `virsh define` wurde vergessen.

### cgroup_device_acl für Eingabegeräte

Alle `/dev/input/event0` bis `/dev/input/event299` müssen in der ACL stehen, da die Event-Nummern
dynamisch vergeben werden (virtuelle UInput-Geräte bekommen oft hohe Nummern). Generiert mit:

```nix
eventDevices = builtins.genList (i: ''"/dev/input/event${toString i}"'') 300;
```

---

## 4. Audio (Scream)

### Wie es funktioniert

1. **Windows**: Scream Virtual Sound Card Treiber (installiert im Test Mode)
2. Scream sendet Audio als UDP-Multicast auf Port 4010
3. **Linux**: `scream` Receiver empfängt auf `virbr0` und gibt über PipeWire aus

### Windows-Setup

- Windows Test Mode aktiviert: `bcdedit /set testsigning on`
- Scream-Treiber installiert via `pnputil /add-driver Scream.inf`
- Manuell als Legacy-Hardware hinzugefügt (Geräte-Manager → Aktion → Ältere Hardware hinzufügen)
- Als Standard-Wiedergabegerät gesetzt

### Linux-Setup (`home.nix`)

```nix
systemd.user.services.scream = {
  Unit.Description = "Scream Audio Receiver";
  Service = {
    ExecStart = "${pkgs.scream}/bin/scream -i virbr0";
    Restart = "always";
    RestartSec = 3;
  };
  Install.WantedBy = [ "default.target" ];
};
```

### Firewall

```nix
networking.firewall.allowedUDPPorts = [ 4010 ];
```

---

## 5. VM starten & stoppen

### Voraussetzung: gpuvm-Modus

Die VM benötigt exklusiven GPU-Zugriff via vfio-pci. Dafür muss zuerst in den
**gpuvm-Modus** gewechselt werden (siehe Section 9). Im gpulinux-Modus startet `vm start`
mit einer Fehlermeldung.

### `vm` Script (empfohlen)

```bash
vm start    # GPU-Check → USB-Check → Festplatten unmounten → VM starten → Looking Glass
vm stop     # Looking Glass beenden → VM herunterfahren (max 60s, dann force)
vm pause    # VM einfrieren (Looking Glass beenden)
vm resume   # VM fortsetzen (Looking Glass neu starten)
vm status   # Zeigt ob VM läuft
vm fixcon   # DualSense Controller neu verbinden (hot-reconnect)
```

**Was `vm start` macht:**
1. Prüft ob GPU auf `vfio-pci` (gpuvm-Modus) — bricht ab wenn nicht
2. Prüft ob DualSense und Azeron Keypad angeschlossen sind
3. Unmountet `/dev/sdb1` und `/dev/nvme0n1p*` (falls gemountet)
4. Startet die VM via `virsh start` (GPU war bereits beim Boot an vfio-pci gebunden)
5. Zeigt Fortschrittsbalken (30s) während Windows bootet
6. Startet Looking Glass Client
7. Background-Watcher: räumt automatisch auf wenn VM stoppt

**Was `vm stop` macht:**
1. Beendet Looking Glass Client
2. Schickt ACPI-Shutdown an die VM
3. Wartet max 60 Sekunden auf sauberes Herunterfahren
4. Falls VM nicht reagiert: erzwingt Shutdown via `virsh destroy`
5. GPU bleibt auf vfio-pci bis zum nächsten Reboot

### Manuell (falls nötig)

```bash
# VM starten (nur im gpuvm-Modus)
sudo virsh start windows11
looking-glass-client -F -f /dev/kvmfr0 win:size=2560x1440 win:dontUpscale=on \
  input:captureOnFocus=no input:grabKeyboardOnFocus=no spice:enable=no

# VM sauber herunterfahren
sudo virsh shutdown windows11

# VM hart stoppen
sudo virsh destroy windows11
```

### VM Autostart

VM-Autostart ist deaktiviert (`onBoot = "ignore"` in configuration.nix).
Die VM startet nur manuell über `vm start` oder `virsh start`.

### VM neu definieren (nach XML-Änderung)

```bash
sudo virsh destroy windows11          # Falls läuft
sudo virsh undefine windows11 --nvram # --nvram ist Pflicht (UEFI)
sudo virsh define /home/leonardn/nixos-config/vm/windows11.xml
sudo virsh start windows11
```

**Wichtig**: Nach Änderungen an `cgroup_device_acl` muss libvirtd neu gestartet werden:
```bash
sudo systemctl restart libvirtd
```

---

## 6. Bekannte Probleme & Lösungen

### LG Client: "host application seems to not be running"
- **Ursache 1**: Host-App läuft nicht in Windows → manuell starten
- **Ursache 2**: IVSHMEM über `<shmem>` statt `qemu:commandline` konfiguriert (verschiedene Speicherbereiche!)
- **Ursache 3**: `/dev/kvmfr0` falsche Berechtigungen → `sudo chown leonardn:kvm /dev/kvmfr0`

### LG Host: "Failed to create DXGI factory: 0x887a0001"
- **Ursache**: Virtual Display Driver (VDD) nicht installiert
- **Fix**: VDD installieren (https://github.com/VirtualDrivers/Virtual-Display-Driver)

### LG Host: Capture Start → Capture Stop (sofort)
- **Ursache**: Kann mehrere Gründe haben, aber häufigster ist falsches IVSHMEM-Mapping (siehe oben)
- Mit korrektem KVMFR-Mapping stoppt der Host nur kurz wenn kein Client subscribed ist und startet automatisch neu

### LG Host als Service: Session 0 Fehler
- **Ursache**: Windows-Services laufen in Session 0, die keinen Desktop/DXGI-Zugriff hat
- **Fix**: Host als reguläre Anwendung starten, NICHT als Service

### VM startet nicht: "can't open backing store /dev/kvmfr0"
- **Ursache**: `/dev/kvmfr0` nicht in `cgroup_device_acl` oder libvirtd nicht neugestartet
- **Fix**: ACL anpassen + `sudo systemctl restart libvirtd`

### IVSHMEM already in use
- **Ursache**: Zweite Instanz des LG Host gestartet
- **Fix**: Alte Instanz beenden (Task Manager)

### Maus wechselt nicht mit Scroll Lock
- **Ursache**: Maus muss VOR den Tastaturen definiert werden (Slave vor Masters)
- **Ursache 2**: Falsches Event-Device (z.B. nach Kabelwechsel)

---

## 7. Festplatten-Passthrough

### Durchgereichte Laufwerke

| Device | Größe | Typ | VM-Target | Inhalt |
|---|---|---|---|---|
| `/dev/sdb` | 931.5 GB | WD Black HDD | vdb (virtio) | NTFS, Spiele |
| `/dev/nvme0n1` | 1.9 TB | Kingston KC3000 NVMe | vdc (virtio) | NTFS, Spiele + alte Windows-Installation |

### Wichtig: Gleichzeitiger Zugriff vermeiden!

Linux und die VM dürfen **NICHT gleichzeitig** auf dieselben Laufwerke zugreifen — das führt zu
Datenverlust. Das `vm` Script unmountet die Laufwerke automatisch vor dem VM-Start.

Nach `vm stop` werden die Laufwerke von KDE automatisch wieder gemountet (udisks2).

### NVMe in Windows

Die NVMe enthält eine alte Windows-Installation. Windows weist dem Daten-Laufwerk nicht automatisch
einen Buchstaben zu. Fix: **Datenträgerverwaltung** → Rechtsklick auf 1.9TB Partition →
"Laufwerkbuchstaben und -pfade ändern" → Buchstabe zuweisen (z.B. `D:`).

### Spiele in Steam/Epic aktivieren

- **Steam**: Einstellungen → Speicher → "+" → Pfad zum SteamLibrary-Ordner (z.B. `D:\SteamLibrary`)
- **Epic Games**: Spiel in Bibliothek → "Installieren" → Pfad zum vorhandenen Ordner wählen → Epic verifiziert vorhandene Dateien

### XML-Konfiguration

```xml
<!-- 1TB WD HDD (Spiele) -->
<disk type="block" device="disk">
  <driver name="qemu" type="raw" cache="none" io="native"/>
  <source dev="/dev/sdb"/>
  <target dev="vdb" bus="virtio"/>
</disk>

<!-- 2TB Kingston NVMe (Spiele) -->
<disk type="block" device="disk">
  <driver name="qemu" type="raw" cache="none" io="native"/>
  <source dev="/dev/nvme0n1"/>
  <target dev="vdc" bus="virtio"/>
</disk>
```

---

## 8. USB-Passthrough

### Durchgereichte USB-Geräte

| Gerät | Vendor:Product | Beschreibung |
|---|---|---|
| DualSense PS5 | 054c:0ce6 | Wireless Controller (Haptic Feedback, Adaptive Triggers) |
| Azeron Keypad | 16d0:12f7 | Gaming Keypad |

USB-Geräte werden per Vendor/Product-ID durchgereicht. Dadurch funktioniert Hotplug —
das Gerät wird automatisch erkannt wenn es eingesteckt wird (auch im laufenden Betrieb).

### XML-Konfiguration

```xml
<hostdev mode="subsystem" type="usb" managed="yes">
  <source>
    <vendor id="0x054c"/>
    <product id="0x0ce6"/>
  </source>
</hostdev>

<hostdev mode="subsystem" type="usb" managed="yes">
  <source>
    <vendor id="0x16d0"/>
    <product id="0x12f7"/>
  </source>
</hostdev>
```

### Live Hotplug (ohne VM-Neustart)

```bash
sudo virsh attach-device windows11 --live /dev/stdin <<< \
  '<hostdev mode="subsystem" type="usb" managed="yes"><source><vendor id="0x16d0"/><product id="0x12f7"/></source></hostdev>'
```

### Automatisiertes DualSense Re-Attach

Wenn der DualSense Controller mitten im Spiel getrennt und wieder verbunden wird (z.B. wenn das Ladekabel angesteckt wird), führt QEMU/libvirt standardmäßig kein erneutes Passthrough aus, obwohl das Gerät in der XML steht.
Dies wurde über eine Kombination aus `udev`-Regel und systemd-Service (`vm-controller-reattach.service`) automatisiert:
1. Eine udev-Regel erkennt den angeschlossenen DualSense (`054c:0ce6`) und löst den Service aus.
2. Der Oneshot-Service ruft ein Bash-Script (`vm-fixcon`) auf, das per `virsh domstate` prüft, ob die VM läuft.
3. Ist die VM aktiv, führt das Script einen `virsh detach-device` gefolgt von einem `virsh attach-device` mit einer XML-Definition für den Controller durch, um ihn sofort live in die Windows-VM einzubinden.

---

## 9. GPU-Modus-Switch (gpulinux ↔ gpuvm)

### Übersicht

Das System hat zwei stabile Boot-Modi für die GPU:

| Modus | GPU-Treiber | Verwendung |
|---|---|---|
| **gpulinux** (Standard) | nvidia (PRIME Offload) | Rocket League nativ, normaler Desktop |
| **gpuvm** | vfio-pci (Passthrough) | Windows VM mit GPU |

Der Wechsel erfordert einen Reboot. Hot-Swap (ohne Reboot) wurde intensiv untersucht und ist
nicht realisierbar: `nvidia_drm` hält 3 kernel-interne DRM-Referenzen, die sich nicht
entladen lassen solange der Treiber aktiv ist — auch nicht nach SDDM-Stop oder fuser-kill.

### Funktionsweise (NixOS Specialisation)

In `hosts/leonardn/default.nix` ist eine NixOS-Specialisation `gpuvm` definiert:

```nix
specialisation.gpuvm.configuration = {
  system.nixos.tags = [ "gpuvm" ];
  boot.kernelParams = lib.mkForce [
    "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on"
    "i915.force_probe=a780"
    "vfio-pci.ids=10de:2206,10de:1aef"  # RTX 3080 + Audio → vfio-pci beim Boot
    "gpu_mode=vm"                         # Erkennungs-Marker für Scripts
  ];
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];  # kein nvidia nötig
  hardware.nvidia.prime.offload.enable = lib.mkForce false;
  hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;
};
```

**Warum das funktioniert:** `vfio-pci.ids` bindet die GPU im Kernel-Early-Boot an vfio-pci,
noch bevor der nvidia-Treiber in Stage 2 geladen wird. Es gibt keinen hängenden
`remove()`-Callback und kein Refcount-Problem — der Treiber sieht die GPU gar nicht erst.

Im gpuvm-Modus zeigt `readlink /sys/bus/pci/devices/0000:01:00.0/driver` → `vfio-pci`.
libvirt erkennt das bei `virsh start` und startet QEMU direkt ohne weiteres Binding.

### Scripts

```bash
# Aktuellen Modus anzeigen
gpu-status

# Modus wechseln (Auto-Toggle, oder explizit: vm | linux)
gpu-switch-reboot
gpu-switch-reboot vm
gpu-switch-reboot linux
```

**`gpu-switch-reboot vm`** sucht den gpuvm-Bootentry in `/boot/loader/entries/`
und setzt ihn via `bootctl set-oneshot` als einmaligen Next-Boot-Entry. Der nächste Reboot
bootet automatisch in die gpuvm-Specialisation, danach kehrt der Bootloader zum Standard
(gpulinux) zurück.

**`gpu-switch-reboot linux`** führt einfach `reboot` aus — der Standard-Bootentry
ist immer gpulinux.

### Vollständiger Workflow

```
# → VM spielen:
gpu-switch-reboot vm    # setzt One-Shot-Boot + rebootet
# [Reboot in gpuvm-Specialisation]
vm start                # VM startet sofort (GPU bereits auf vfio-pci)

# → Rocket League spielen:
gpu-switch-reboot linux # rebootet in Standard-Modus
# [Reboot in gpulinux]
# Heroic/RL starten
```

### Sicherheitsprüfungen

**`vm start` im falschen Modus:**
```
Fehler: GPU ist auf 'nvidia', nicht vfio-pci.
Lösung: 'gpu-switch-reboot' ausführen → Reboot → dann 'vm start'
```

**Heroic/Rocket League im falschen Modus:**
Beim Start von Heroic (aus dem Launcher oder Terminal) erscheint eine `notify-send`-Warnung:
```
Falscher GPU-Modus
Du bist im gpuvm-Modus! Rocket League braucht gpulinux.
Ausführen: gpu-switch-reboot linux
```
Implementiert via Heroic-Wrapper-Script (`home/desktop-niri.nix`) + `xdg.desktopEntries`-Override.

### libvirt-Hook (release/end)

Der Hook in `vm/libvirt-hooks.nix` läuft nach VM-Stop. Im gpuvm-Modus tut er nichts
(GPU bleibt auf vfio-pci für weitere VM-Sessions ohne Reboot). Im gpulinux-Modus würde er
GPU an nvidia zurückbinden — dieser Pfad ist aber derzeit nie aktiv.

```bash
if grep -q 'gpu_mode=vm' /proc/cmdline; then
  # GPU bleibt auf vfio-pci
  exit 0
fi
# Sonst: Rebind an nvidia (für künftigen Hot-Swap-Modus)
```

### Warum kein Hot-Swap?

Untersucht und verworfen. `nvidia_drm` hat Refcount=3 (DRM-Device-Registration ×2 +
fbdev-Konsole). Diese Refs sind kernel-intern und können nicht durch User-Prozess-Kill
oder SDDM-Stop aufgelöst werden. `virsh nodedev-detach` hängt deshalb in `remove()`.

Getestete Ansätze die alle scheiterten:

| Ansatz | Problem |
|---|---|
| `modprobe -r nvidia_drm` nach SDDM-Stop | Refcount=3, kernel-intern, nicht entladbar |
| `virsh nodedev-detach` direkt | Hängt in `remove()` wegen DRM-Refs |
| `nvidia-drm.fbdev=0` Kernel-Param | NixOS überschreibt mit `fbdev=1` (Treiber ≥545) |
| `hardware.nvidia.open = true` | Refcount bleibt 3, Verhalten identisch |
| SDDM-Stop vor Detach | Verschlimmert das Hängen (DRM-State halb aufgeräumt) |

---

## 10. Netzwerk

Die VM nutzt das libvirt NAT-Netzwerk `default` (192.168.122.0/24):
- VM bekommt IP via DHCP (meist 192.168.122.x)
- Host ist erreichbar unter 192.168.122.1
- Scream Audio und alle VM↔Host-Kommunikation läuft über `virbr0`

---

## 11. Clipboard-Sync (nicht fertiggestellt, zum Wiederaufgreifen)

### Ziel

Bidirektionaler Clipboard-Sync zwischen Linux-Host und Windows-VM. SPICE-Clipboard wurde
bewusst deaktiviert (`spice:enable=no`) weil es mit Looking Glass kollidiert. Input Leap
wurde als zu schwergewichtig abgelehnt (ganzer KVM-Stack nur für Clipboard).

### Gewählter Ansatz

TCP-basierter Clipboard-Sync über `virbr0` (192.168.122.0/24):

```
Linux (192.168.122.1)                    Windows VM (192.168.122.111)
─────────────────────                    ────────────────────────────
Polling-Loop (500ms)                     PowerShell Listener :5556
  wl-paste → hash-check                   → Set-Clipboard
  → socat TCP → VM:5556

socat TCP-LISTEN:5557 ◄──────────────   PowerShell Poller (500ms)
  → wl-copy                               → Get-Clipboard → TcpClient → Host:5557
```

- Jede Clipboard-Änderung = neue TCP-Verbindung, EOF = Nachrichtenende (kein Framing nötig)
- Anti-Ping-Pong via SHA-256-Hash des letzten gesendeten/empfangenen Inhalts
- Text-only, max 10 MB
- Firewall: TCP 5557 auf Linux öffnen (5556 auf Windows-Seite)

### Was bereits implementiert und getestet war

**Linux-Seite (danach revertiert):**
- `vm/vm.nix`: `socat` als Paket, zwei `writeShellScript`-Scripts, zwei systemd User-Services
  (Pattern wie Scream-Service)
- `vm/gpu-passthrough.nix`: `networking.firewall.allowedTCPPorts = [ 5557 ]`
- TCP-Verbindung zu Windows:5556 hat funktioniert (verifiziert per `socat` manuell)
- Linux-Service lief stabil (Polling-Loop aktiv, `sleep 0.5` im Prozessbaum sichtbar)

**Windows-Seite (`vm/clipboard-sync.ps1` liegt noch im Repo):**
- TCP-Listener auf Port 5556 (Background-Runspace)
- Polling-Sender alle 500ms (`Get-Clipboard` → TcpClient)
- SHA-256-Deduplication
- Windows-Firewall-Regel: TCP 5556 inbound erlaubt (bereits eingerichtet)
- Autostart-Shortcut in `shell:startup` (bereits eingerichtet)

### Gefundene Bugs (alle gefixt im Revert-Stand)

| Bug | Ursache | Fix |
|-----|---------|-----|
| `wl-paste --watch` schlägt fehl | KDE Plasma 6 / KWin unterstützt `zwlr_data_control_manager_v1` nicht | Auf 500ms-Polling mit `wl-paste --no-newline` umgestellt |
| `sleep: command not found` | Nix `writeShellScript` hat kein PATH | `export PATH="..."` am Scriptanfang mit allen nötigen Paketen |
| `virsh net-dhcp-leases default` leer | `virtnetworkd` findet `dnsmasq` nicht im PATH | Auf `ip neigh show dev virbr0` umgestellt |
| awk-Filter liefert leere VM-IP | `$3=="lladdr"` falsch, korrekt ist `$2=="lladdr"` | Filter korrigiert (aber revertiert bevor getestet) |

### Was noch offen ist

1. **awk-Fix verifizieren**: Der letzte Fix (`$2=="lladdr"`) war korrekt (manuell getestet),
   aber der Rebuild wurde revertiert bevor der End-to-End-Test abgeschlossen war.

2. **Set-Clipboard in PowerShell-Runspace**: Möglicherweise STA-Thread-Problem.
   Workaround bereits im Script: `$rs.ApartmentState = [System.Threading.ApartmentState]::STA`.
   Ob das ausreicht ist unklar — der Windows-Empfang war noch nicht verifiziert.
   Alternativ: `clip.exe` statt `Set-Clipboard` verwenden (keine Threading-Probleme,
   aber schlechtere Unicode-Unterstützung).

3. **Windows→Linux-Richtung**: Komplett ungetestet.

### VM-IP ermitteln (wichtig)

`virsh net-dhcp-leases default` funktioniert nicht (dnsmasq-Problem). Stattdessen:

```bash
ip neigh show dev virbr0 | awk '$2=="lladdr" {print $1}' | head -1
```

Liefert die aktuelle VM-IP (z.B. `192.168.122.111`).

### Nix-Script PATH-Template

Alle Tools müssen in Nix-Scripts explizit im PATH sein:

```nix
export PATH="${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.iproute2}/bin:${pkgs.socat}/bin:${pkgs.wl-clipboard}/bin"
```

### Wiederaufnahme

Den Revert-Commit rückgängig machen und mit dem awk-Fix + Windows-Test weitermachen.
Der Code liegt in `vm/clipboard-sync.ps1` (Windows-Seite, noch im Repo).
Linux-Seite muss in `vm/vm.nix` und `vm/gpu-passthrough.nix` neu eingetragen werden.
