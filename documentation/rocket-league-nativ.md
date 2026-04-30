# Rocket League nativ auf leonardn

**Letzte Aktualisierung:** 2026-04-29  
**Commits Session 1:** `a24828e` → `4ca35f0` → `0abc332` → `7a7738a`  
**Commits Session 2:** `c1e8533`

---

## Hardware

| Komponente | Details |
|---|---|
| CPU | Intel Core i5-14600K |
| iGPU | Intel UHD 770 (`8086:a780`, PCI `00:02.0`) |
| dGPU | NVIDIA RTX 3080 GA102 (`10de:2206`, PCI `01:00.0`) |
| Nvidia Audio | GA102 HD Audio (`10de:1aef`, PCI `01:00.1`) |
| Monitor 1 | GIGABYTE M27Q — DP-1, 2560x1440@170Hz, VRR-fähig |
| Monitor 2 | Ancor VG248 — HDMI-A-1, 1920x1080@60Hz |
| Boot-SSD | `/dev/sdb` (ext4 root + EFI) |
| HDD | `/dev/sda1` — 931 GB NTFS, Label "HDD" |
| NVMe | `/dev/nvme0n1p3` — 1,9 TB NTFS (Windows-Partition) |

---

## Ausgangssituation (vor Session 1)

**`vm/gpu-passthrough.nix`:**
```nix
boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "vfio-pci.ids=10de:2206,10de:1aef" "random.trust_cpu=on" ];
boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];
boot.kernelModules = [ "kvmfr" ];
```
→ RTX 3080 + Audio statisch an `vfio-pci` gebunden. Nvidia-Treiber konnte nicht laden.

**`system/hardware.nix`:**
```nix
hardware.graphics.enable = true;
services.xserver.videoDrivers = [ "modesetting" ];
```

**`system/packages.nix`:**
```nix
programs.steam.enable = true;
```

**Libvirt VM-XML:** GPU-Passthrough war bereits mit `managed='yes'` konfiguriert:
```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
```
→ Libvirt kann die GPU beim VM-Start automatisch von `nvidia` → `vfio-pci` umhängen.

---

## Ziel

1. RTX 3080 nach Boot dem Host zuteilen (proprietärer Nvidia-Treiber)
2. Rocket League über Heroic Games Launcher + GE-Proton + PRIME-Offload nativ spielen
3. VM-Switching bleibt dynamisch: libvirt detacht GPU beim `virsh start windows11` automatisch
4. Gaming-Tools: MangoHud, Gamemode

---

## Session 1 — Grundimplementierung

### `system/hardware.nix` — 32-Bit-Grafik (Commit `a24828e`)

```diff
-hardware.graphics.enable = true;
+hardware.graphics = {
+  enable = true;
+  enable32Bit = true;    # Pflicht für Proton/Wine
+};
```

### `system/nvidia.nix` — Neue Datei (Commit `a24828e`)

```nix
{ config, lib, ... }:
{
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" "modesetting" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId  = "PCI:0:2:0";   # Intel UHD 770  (00:02.0)
      nvidiaBusId = "PCI:1:0:0";   # RTX 3080       (01:00.0)
    };
  };
}
```

### `hosts/leonardn/default.nix` — Import ergänzt (Commit `a24828e`)

```diff
  ../../system/hardware.nix
+ ../../system/nvidia.nix
  ../../vm/gpu-passthrough.nix
```

### `vm/gpu-passthrough.nix` — Statisches VFIO entfernt (Commit `a24828e`)

```diff
-boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "vfio-pci.ids=10de:2206,10de:1aef" "random.trust_cpu=on" ];
+boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" ];

-boot.kernelModules = [ "kvmfr" ];
+boot.kernelModules = [ "kvmfr" "vfio" "vfio_iommu_type1" "vfio_pci" ];
```

### `system/packages.nix` — Gaming-Programme (Commit `a24828e`)

```diff
-programs.steam.enable = true;
+programs.steam = {
+  enable = true;
+  remotePlay.openFirewall = true;
+  extraCompatPackages = with pkgs; [ proton-ge-bin ];
+};
+programs.gamemode.enable = true;
+programs.gamescope.enable = true;
```

### `home/desktop-niri.nix` — Heroic + Tools (Commit `a24828e`)

```diff
  home.packages = with pkgs; [
+   heroic        # Epic/GOG Games Launcher (Rocket League via Proton)
+   protonup-qt   # Proton-GE-Builds verwalten
+   mangohud      # FPS/GPU-Overlay
    fuzzel
```

---

## Problem 1: Black Screen nach erstem Reboot

### Symptom
Nach Rebuild + Reboot → komplett schwarzer Bildschirm, kein SDDM, kein Login.

### Diagnose (`journalctl --boot=-1`)

```
niri: error creating renderer for primary GPU: Error::NoDevice(DrmNode { dev: 57856, ty: Primary })
niri: error adding device: Failed to open device: Invalid argument (os error 22)
niri: failed to initialize renderer: software EGL renderers are not supported
```

### Ursache
Die NixOS `hardware.nvidia.prime.offload`-Konfiguration erzeugt udev-Regeln, die das Intel-DRM-Device (`/dev/dri/card0`) für PRIME-Handoff sperren. Niri versucht es direkt per `drmSetMaster` zu öffnen und bekommt `EINVAL`.

Zweites Problem: Intel UHD 770 hat Device-ID `8086:a780`. Ohne `i915.force_probe=a780` übernimmt `simpledrm` (Generic Framebuffer) das Device vor `i915` — PRIME funktioniert dann nicht.

### Fix: PRIME-Block entfernt (Commit `4ca35f0`)

`system/nvidia.nix` temporär ohne `prime`-Block:
```nix
{ config, lib, ... }:
{
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nirdSettings = true;
    open = false;
    # Kein prime-Block: NixOS-PRIME-udev-Regeln blockieren Niri vom Intel-DRM-Device
  };
}
```

→ Niri startet wieder. Nvidia-Treiber läuft, aber PRIME-Offload noch nicht korrekt aktiv.

---

## NVMe-Automount (Commit `0abc332`)

Rocket League liegt nicht auf der HDD, sondern auf der Windows-NVMe-Partition:

```
/mnt/nvme/Program Files/Epic Games/rocketleague/Binaries/Win64/RocketLeague.exe
```

Partitionslayout der NVMe:
```
nvme0n1p1   100M  vfat   (Windows EFI)
nvme0n1p2    16M         (Windows MSR)
nvme0n1p3   1.9T  ntfs   (Windows C:)
```

In `hosts/leonardn/default.nix` ergänzt:
```nix
fileSystems."/mnt/nvme" = {
  device = "/dev/nvme0n1p3";
  fsType = "ntfs3";
  options = [ "uid=1000" "gid=100" "umask=0022" "nofail" "noauto" "x-systemd.automount" ];
};
```

- `noauto + x-systemd.automount`: Wird nur bei Zugriff gemountet, nicht beim Boot
- `nofail`: Boot schlägt nicht fehl wenn NVMe fehlt
- Der `vm`-Script unmountet `/dev/nvme0n1p3` vor dem VM-Start automatisch

---

## Fix: `i915.force_probe=a780` + PRIME reaktiviert (Commit `7a7738a`)

### `vm/gpu-passthrough.nix`

```diff
-boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" ];
+boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" "i915.force_probe=a780" ];
```

`i915.force_probe=a780` zwingt den i915-Treiber, die Intel UHD 770 zu beanspruchen bevor `simpledrm` es tut. Danach können die PRIME-udev-Regeln korrekt greifen und Niri kann das DRM-Device öffnen.

### `system/nvidia.nix` — mit PRIME reaktiviert

```nix
{ config, lib, ... }:
{
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId  = "PCI:0:2:0";   # Intel UHD 770  (00:02.0)
      nvidiaBusId = "PCI:1:0:0";   # RTX 3080       (01:00.0)
    };
  };
}
```

---

## Session 2 — VK_SUBOPTIMAL_KHR & Stabilität

### Problem 2: VK_SUBOPTIMAL_KHR Crash-Loop (persistiert nach Session 1)

#### Symptom
- Spiel startet, läuft aber stark laggy
- Absturz nach ~1 Minute
- MangoHud-Overlay zeigt nichts

#### Log (`~/.local/state/Heroic/logs/games/Sugar_legendary/launch.log`)

```
info:  Presenter: Got VK_SUBOPTIMAL_KHR, recreating swapchain
info:  Presenter: Got VK_SUBOPTIMAL_KHR, recreating swapchain
... [636–1604 Mal, je nach Run]
err:   Presenter: Failed to create Vulkan swapchain: VK_SUBOPTIMAL_KHR
```

#### Root Cause — Diagnose

**Wichtige Erkenntnis aus dem Log:** Wine/Proton initialisiert automatisch den Wayland-Treiber (`waylanddrv`), sobald `WAYLAND_DISPLAY` in der Umgebung gesetzt ist — unabhängig von der `enableWineWayland`-Einstellung in Heroic. Das bedeutet:

```
Rocket League (D3D11)
  → DXVK (Vulkan, VK_KHR_win32_surface via Wine Win32-Layer)
    → Wine Wayland-Driver (waylanddrv, Wayland-Backend)
      → Wayland-Surface auf niri (Intel-Compositor)
        → Nvidia rendert via PRIME-Offload, Frames werden kopiert
```

**Warum VK_SUBOPTIMAL_KHR?**  
DXVK wählt `VK_PRESENT_MODE_MAILBOX_KHR` (kein VSync). Nvidia's Vulkan-WSI gibt bei Wayland-Surfaces für MAILBOX-Modus `VK_SUBOPTIMAL_KHR` zurück, weil `VK_PRESENT_MODE_FIFO_KHR` der native Wayland-Präsentationsmodus ist. DXVK erstellt den Swapchain neu → bekommt wieder VK_SUBOPTIMAL_KHR → Endlosschleife bis Crash.

#### Fehlversuch: Gamescope deaktivieren

Ursprüngliche Theorie: Gamescope läuft auf Intel, Spiel auf Nvidia → Cross-GPU-Swapchain → VK_SUBOPTIMAL_KHR.

Gamescope in `Sugar.json` auf `"enable": false` gesetzt → **kein Effekt**, VK_SUBOPTIMAL_KHR weiterhin 1604×. Ursache liegt tiefer im Wayland-WSI-Layer, nicht in Gamescope.

Gamescope bleibt deaktiviert (weniger Overhead, kein extra Compositor-Layer).

#### Fix: DXVK FIFO-Modus erzwingen

FIFO (`VK_PRESENT_MODE_FIFO_KHR`) ist der native Wayland-Modus. Nvidia gibt dafür kein `VK_SUBOPTIMAL_KHR` zurück.

**`~/.config/heroic/dxvk-rl.conf`** (neue Datei):
```
dxgi.syncInterval = 1
```

`syncInterval = 1` erzwingt VSync/FIFO in DXVK für D3D11-Spiele. FPS werden auf Monitor-Refreshrate gedeckelt (170Hz → max 170fps), was für Rocket League ausreichend ist.

In Heroic unter **Rocket League → Einstellungen → Umgebungsvariablen**:
```
DXVK_CONFIG_FILE = /home/leonardn/.config/heroic/dxvk-rl.conf
```

**Wichtig:** Wenn Einstellungen in Heroic's UI geändert werden, werden die `enviromentOptions` aus der `Sugar.json` überschrieben. Die `DXVK_CONFIG_FILE`-Variable muss danach ggf. erneut eingetragen werden.

### Fix: VRR auf DP-1 aktivieren (Commit `c1e8533`)

Der GIGABYTE M27Q unterstützt FreeSync (VRR), war aber deaktiviert. In `home/desktop-niri.nix`:

```diff
  output "DP-1" {
    mode "2560x1440@170.001"
    position x=0 y=0
+   variable-refresh-rate
  }
```

**Wichtig zur KDL-Syntax:** Niri's `variable-refresh-rate` nimmt in dieser Version kein Argument. Weder `variable-refresh-rate on-demand` (Identifier-Fehler) noch `variable-refresh-rate "on-demand"` (String-Argument-Fehler) funktionieren — nur die bare Node ohne Argument.

---

## Aktuelle Heroic-Konfiguration (`~/.config/heroic/GamesConfig/Sugar.json`)

Rocket League hat die Epic-App-ID `Sugar`.

| Setting | Wert | Bedeutung |
|---|---|---|
| `nvidiaPrime` | `true` | Setzt `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only` |
| `useGameMode` | `true` | CPU auf Performance-Governor via `gamemoderun` |
| `wrapperOptions` | `[{ "mangohud": "" }]` | MangoHud als Wrapper-Prozess |
| `showFps` | `true` | Heroic eigener FPS-Counter (zuverlässig, Overlay unabhängig) |
| `wineVersion` | GE-Proton-latest | Via protonup-qt installiert |
| `eacRuntime` | `true` | Easy Anti-Cheat Linux-Runtime |
| `battlEyeRuntime` | `true` | BattlEye Linux-Runtime |
| `autoInstallDxvk` | `true` | DXVK DirectX→Vulkan |
| `autoInstallDxvkNvapi` | `true` | NVAPI-Emulation (RTX-Features) |
| `autoInstallVkd3d` | `true` | VKD3D DirectX 12→Vulkan |
| `gamescope.enable` | `false` | Deaktiviert (war kein Fix für VK_SUBOPTIMAL_KHR, nur Overhead) |
| `enableFsync` | `true` | Fsync für bessere Wine-Performance |
| `enableEsync` | `true` | Esync für bessere Wine-Performance |

**Env-Var manuell eintragen (nach Heroic-UI-Änderungen prüfen):**
```
DXVK_CONFIG_FILE = /home/leonardn/.config/heroic/dxvk-rl.conf
```

---

## DualSense Controller

### Status
Funktioniert out-of-the-box via USB. Keine zusätzliche NixOS-Konfiguration nötig.

### Warum es funktioniert
- `hid_playstation` Kernel-Modul ist geladen (handelt DualSense-Protokoll inkl. Rumble, Touchpad, Gyro)
- `programs.steam.enable = true` installiert systemweite udev-Regeln (`/etc/udev/rules.d/60-steam-input.rules`), die auch ohne Steam gelten:
  ```
  # PS5 DualSense controller over USB hidraw
  KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
  # PS5 DualSense controller over bluetooth hidraw
  KERNEL=="hidraw*", KERNELS=="*054C:0DF2*", MODE="0660", TAG+="uaccess"
  ```
- User `leonardn` ist in der `input`-Gruppe → Zugriff auf `/dev/input/event*` und `/dev/input/js*`
- systemd-udev setzt ACL auf `/dev/hidraw*` für die aktive Session (TAG+="uaccess")
- GE-Proton enthält SDL2 mit eingebautem DualSense-Mapping

### Verbindung herstellen
USB: DualSense via USB-C einstecken → sofort erkannt als:
- `/dev/input/js3` + `/dev/input/event22` — Buttons/Achsen
- `/dev/input/event23` — Motion Sensors
- `/dev/hidraw21` — Raw HID (Rumble, Touchpad)

In Rocket League: **Einstellungen → Steuerung → Controller-Modus** aktivieren.

---

## MangoHud

MangoHud lädt, aber das `Shift+F12`-Overlay-Toggle funktioniert nicht zuverlässig im Wine-Wayland-Context. Workaround: Heroic's eingebauten FPS-Counter nutzen (`showFps: true`).

Grundlegende VRAM/GPU-Nutzung lässt sich alternativ mit `nvidia-smi` prüfen:
```bash
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits
```

---

## Verifikation

```bash
# Nvidia-Treiber aktiv und VRAM-Nutzung während Rocket League
nvidia-smi
# → RTX 3080, Driver 595.58.03, CUDA 13.2

# VRAM-Nutzung prüfen
nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv
# → <PID>, ~1600 MiB, RocketLeague.exe

# DualSense erkannt
cat /proc/bus/input/devices | grep -A3 "DualSense"
# → Name="Sony Interactive Entertainment DualSense Wireless Controller"
# → Handlers=event22 js3

# VK_SUBOPTIMAL_KHR im letzten Log zählen (sollte 0 sein mit dxvk-rl.conf)
grep -c "VK_SUBOPTIMAL_KHR" ~/.local/state/Heroic/logs/games/Sugar_legendary/launch.log
```

---

## GPU-Modus-Switch (Rocket League ↔ Windows VM)

Rocket League und die Windows VM nutzen beide die RTX 3080, können aber nicht gleichzeitig
laufen. Der Wechsel erfolgt per `gpu-switch-reboot` (Reboot erforderlich, Hot-Swap nicht möglich).

```bash
# → Rocket League spielen (Standard nach jedem Reboot):
gpu-status              # zeigt: gpulinux (PRIME Offload)
# Heroic starten, RL spielen

# → Windows VM spielen:
gpu-switch-reboot vm    # setzt One-Shot-Boot + rebootet
# Nach Reboot: gpu-status zeigt gpuvm
vm start

# → Zurück zu Rocket League:
gpu-switch-reboot linux # rebootet in Standard-Modus
```

**Sicherheitswarnung:** Wenn Heroic im gpuvm-Modus gestartet wird, erscheint eine
`notify-send`-Warnung. Heroic läuft trotzdem, aber Rocket League kann nicht auf die GPU
zugreifen (RTX 3080 ist unter vfio-pci).

Details zum GPU-Modus-System: `documentation/VM-SETUP.md` Section 9.

---

## Aktueller Stand

**Funktioniert:**
- RTX 3080 rendert Rocket League via PRIME-Offload (~130fps stabil bei 170Hz-Monitor)
- Kein VK_SUBOPTIMAL_KHR-Crash mehr (DXVK FIFO-Config)
- VRR (FreeSync) auf DP-1 aktiv
- DualSense Controller via USB vollständig funktionsfähig (Buttons, Rumble, Touchpad)
- Heroic, GE-Proton, EAC Runtime, BattlEye Runtime aktiv
- i915 auf Intel UHD 770, PRIME-Offload konfiguriert
- GPU-Modus-Switch via `gpu-switch-reboot` (gpulinux ↔ gpuvm)

**Bekannte Einschränkungen:**
- MangoHud `Shift+F12` Overlay-Toggle funktioniert nicht (Wine-Wayland-Kontext) → Heroic FPS-Counter als Ersatz
- `DXVK_CONFIG_FILE` Env-Var wird beim Ändern via Heroic-UI zurückgesetzt → ggf. manuell neu eintragen
- GPU-Wechsel erfordert Reboot (Hot-Swap nicht möglich, siehe VM-SETUP.md Section 9)

**Noch offen:**
- Bluetooth für DualSense (Desktop hat keine BT-Konfiguration — ggf. USB-BT-Adapter nötig)

---

## Alle Commits

| Hash | Nachricht |
|---|---|
| `a24828e` | rocket league nativ + nvidia prime offload + heroic |
| `4ca35f0` | fix: nvidia ohne prime-block, niri kann igpu-drm-device öffnen |
| `0abc332` | nvme windows-partition als /mnt/nvme automount |
| `7a7738a` | fix: nvidia prime offload + i915.force_probe=a780 für niri-kompatibilität |
| `c1e8533` | niri: VRR für DP-1 aktiviert + gamescope deaktiviert |
