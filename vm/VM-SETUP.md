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

Die Tastatur und Maus werden über QEMU `input-linux` direkt an die VM durchgereicht.
Mit **Scroll Lock** kann zwischen Linux und VM gewechselt werden.

### ZSA Voyager Tastatur (2 Interfaces!)

Die Voyager hat **zwei** Keyboard-Interfaces:
- **event-kbd**: Boot Protocol (6KRO) — sendet immer Tastenevents
- **if03-event-kbd**: NKRO Interface — sendet die eigentlichen Tastenanschläge

**Beide** müssen als `input-linux` konfiguriert werden, sonst geht der Toggle nicht richtig:

```xml
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=kbd0,evdev=/dev/input/by-id/usb-ZSA_Technology_Labs_Voyager_q697z_bvmrrP-event-kbd,grab_all=on,repeat=on,grab-toggle=scrolllock"/>
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=kbd1,evdev=/dev/input/by-id/usb-ZSA_Technology_Labs_Voyager_q697z_bvmrrP-if03-event-kbd,grab_all=on,repeat=on,grab-toggle=scrolllock"/>
```

### Maus (Toggle zusammen mit Tastatur)

Die Maus wird als **Slave** definiert (OHNE `grab_all`) und **VOR** den Tastaturen (Masters).
Die Tastaturen propagieren den Toggle-Status an die Maus:

```xml
<qemu:arg value="-object"/>
<qemu:arg value="input-linux,id=mouse,evdev=/dev/input/by-id/usb-Corsair_CORSAIR_SLIPSTREAM_WIRELESS_USB_Receiver_752687B4A4DC9C99-event-mouse"/>
```

**Reihenfolge ist wichtig**: Maus (Slave) ZUERST, dann Tastaturen (Masters mit `grab_all=on`).

### Automatische Maus-Erkennung (kabellos vs. kabelgebunden)

Zwei Corsair-Mäuse (DARKSTAR kabelgebunden, SLIPSTREAM kabellos) teilen sich den Symlink
`/dev/input/vm-mouse`. Per udev-Priorität gewinnt SLIPSTREAM (immer eingesteckt):

```nix
# DARKSTAR (kabelgebunden) - niedrige Priorität
KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", ENV{ID_INPUT_MOUSE}=="1",
  SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=50"

# SLIPSTREAM (kabellos) - hohe Priorität
KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", ENV{ID_INPUT_MOUSE}=="1",
  SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=100"
```

### cgroup_device_acl für Eingabegeräte

Alle `/dev/input/event0` bis `/dev/input/event260` müssen in der ACL stehen, da die Event-Nummern
dynamisch vergeben werden. Generiert mit:

```nix
eventDevices = builtins.genList (i: ''"/dev/input/event${toString i}"'') 261;
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

### `vm` Script (empfohlen)

Das `vm` Script (in `home.nix` definiert) automatisiert den gesamten Ablauf:

```bash
vm start    # Festplatten unmounten → VM starten → Looking Glass starten
vm stop     # Looking Glass beenden → VM herunterfahren (max 60s, dann force)
vm status   # Zeigt ob VM läuft
```

**Was `vm start` macht:**
1. Unmountet `/dev/sdb1` und `/dev/nvme0n1p*` (falls gemountet)
2. Startet die VM via `virsh start`
3. Wartet 2 Sekunden für KVMFR-Initialisierung
4. Startet Looking Glass Client im Hintergrund

**Was `vm stop` macht:**
1. Beendet Looking Glass Client
2. Schickt ACPI-Shutdown an die VM
3. Wartet max 60 Sekunden auf sauberes Herunterfahren
4. Falls VM nicht reagiert: erzwingt Shutdown via `virsh destroy`

### Manuell (falls nötig)

```bash
# VM starten
sudo virsh start windows11
looking-glass-client -f /dev/kvmfr0 win:size=2560x1440 win:dontUpscale=on spice:enable=no

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
sudo virsh define /home/leonardn/windows11.xml
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

---

## 9. Dynamische GPU-Zuweisung (nicht funktionsfähig)

Wir haben versucht, die NVIDIA GPU dynamisch zwischen Linux und VM zu wechseln
(NVIDIA-Treiber auf Linux, bei VM-Start an vfio-pci übergeben). **Das funktioniert aktuell nicht stabil:**

- **NVIDIA Open Kernel Module + KWin Wayland**: `GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT` — KWin
  crasht beim Erstellen von OpenGL-Framebuffern auf der NVIDIA GPU (intermittent)
- **NVIDIA Proprietary Kernel Module**: Kernel-OOPS in `_nv000582kms` bei `nv_drm_framebuffer_create`
- **Multi-GPU KWin**: SDDM und User-Session konkurrieren um DRM-Devices (`Device already taken`)
- **nvidia_drm entladen**: Module haben >40 Referenzen wenn KWin läuft, `modprobe -r` hängt

**Status**: Wir nutzen weiterhin statisches vfio-pci Binding + Looking Glass. Dynamische Zuweisung
könnte mit zukünftigen NVIDIA-Treiber- oder KDE-Updates funktionieren.

---

## 10. Netzwerk

Die VM nutzt das libvirt NAT-Netzwerk `default` (192.168.122.0/24):
- VM bekommt IP via DHCP (meist 192.168.122.x)
- Host ist erreichbar unter 192.168.122.1
- Scream Audio und alle VM↔Host-Kommunikation läuft über `virbr0`
