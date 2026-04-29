# Rocket League nativ auf leonardn

**Datum:** 2026-04-29  
**Commits:** `a24828e` → `4ca35f0` → `0abc332` → `7a7738a`

---

## Ausgangssituation

### Hardware
| Komponente | Details |
|---|---|
| CPU | Intel Core i5-14600K |
| iGPU | Intel UHD 770 (`8086:a780`, PCI `00:02.0`) |
| dGPU | NVIDIA RTX 3080 GA102 (`10de:2206`, PCI `01:00.0`) |
| Nvidia Audio | GA102 HD Audio (`10de:1aef`, PCI `01:00.1`) |
| Boot-SSD | `/dev/sdb` (ext4 root + EFI) |
| HDD | `/dev/sda1` — 931 GB NTFS, Label "HDD" |
| NVMe | `/dev/nvme0n1p3` — 1,9 TB NTFS (Windows-Partition) |

### NixOS-Konfiguration vorher

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
4. Gaming-Tools: MangoHud, Gamescope, Gamemode

---

## Implementierung (Commit `a24828e`)

### `system/hardware.nix` — 32-Bit-Grafik

```diff
-hardware.graphics.enable = true;
+hardware.graphics = {
+  enable = true;
+  enable32Bit = true;    # Pflicht für Proton/Wine
+};
```

### `system/nvidia.nix` — Neue Datei

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

### `hosts/leonardn/default.nix` — Import ergänzt

```diff
  ../../system/hardware.nix
+ ../../system/nvidia.nix
  ../../vm/gpu-passthrough.nix
```

### `vm/gpu-passthrough.nix` — Statisches VFIO entfernt

```diff
-boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "vfio-pci.ids=10de:2206,10de:1aef" "random.trust_cpu=on" ];
+boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" ];

-boot.kernelModules = [ "kvmfr" ];
+boot.kernelModules = [ "kvmfr" "vfio" "vfio_iommu_type1" "vfio_pci" ];
```

### `system/packages.nix` — Gaming-Programme

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

### `home/desktop-niri.nix` — Heroic + Tools

```diff
  home.packages = with pkgs; [
+   heroic        # Epic/GOG Games Launcher (Rocket League via Proton)
+   protonup-qt   # Proton-GE-Builds verwalten
+   mangohud      # FPS/GPU-Overlay (Shift+F12)
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
Die NixOS `hardware.nvidia.prime.offload`-Konfiguration erzeugt udev-Regeln, die das Intel-DRM-Device (`/dev/dri/card0`) für PRIME-Handoff sperren. Niri versucht es direkt per `drmSetMaster` zu öffnen und bekommt `EINVAL` — weil der PRIME-Lock bereits hält.

Zweites Problem: Intel UHD 770 hat Device-ID `8086:a780`. Ohne `i915.force_probe=a780` übernimmt `simpledrm` (Generic Framebuffer) das Device vor `i915` — PRIME funktioniert dann nicht.

### Fix: PRIME-Block entfernt (Commit `4ca35f0`)

`system/nvidia.nix` ohne `prime`-Block:
```nix
{ config, lib, ... }:
{
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    # Kein prime-Block: NixOS-PRIME-udev-Regeln blockieren Niri vom Intel-DRM-Device
  };
}
```

→ Niri startet wieder. Nvidia-Treiber läuft, aber PRIME-Offload noch nicht korrekt aktiv.

---

## NVMe-Automount (Commit `0abc332`)

Rocket League war nicht auf der HDD, sondern auf der Windows-NVMe-Partition:

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

## Problem 2: VK_SUBOPTIMAL_KHR Crash-Loop

### Symptom
- Starkes Lag
- Spiel stürzt nach einiger Zeit ab
- MangoHud `Shift+F12` ohne Effekt

### Log (`~/.local/state/Heroic/logs/games/Sugar_legendary/launch.log`)

```
info:  Presenter: Got VK_SUBOPTIMAL_KHR, recreating swapchain
info:  Presenter: Got VK_SUBOPTIMAL_KHR, recreating swapchain
... [3525 Mal]
```

### Ursache
Nvidia rendert Frames, Intel iGPU präsentiert sie auf dem Display. PRIME-Copy kopiert jeden Frame von Nvidia-VRAM → Intel-VRAM. Niri meldet dem Vulkan-Swapchain, dass er nicht optimal ist (GPU-Wechsel). DXVK erstellt den Swapchain neu → bekommt wieder VK_SUBOPTIMAL_KHR → Endlosschleife bis Crash.

Root Cause: `i915` hatte `8086:a780` nicht korrekt übernommen (simpledrm war schneller), deshalb funktionierte PRIME nicht richtig.

---

## Fix: `i915.force_probe=a780` + PRIME reaktiviert (Commit `7a7738a`)

### `vm/gpu-passthrough.nix`

```diff
-boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" ];
+boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" "i915.force_probe=a780" ];
```

### `system/nvidia.nix` — finale Version

```nix
{ config, lib, ... }:
{
  # Nvidia proprietärer Treiber (RTX 3080) mit PRIME-Offload
  # i915.force_probe=a780 (in gpu-passthrough.nix) sorgt dafür, dass i915 die
  # Intel UHD 770 vor simpledrm beansprucht → Niri kann das DRM-Device öffnen
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

## Heroic Games Config (`~/.config/heroic/GamesConfig/Sugar.json`)

Rocket League hat die Epic-App-ID `Sugar`. Die Datei wird direkt von Heroic gelesen (kein Neustart nötig).

| Setting | Wert | Bedeutung |
|---|---|---|
| `nvidiaPrime` | `true` | Setzt `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only` |
| `useGameMode` | `true` | CPU auf Performance-Governor via `gamemoderun` |
| `enviromentOptions` | `[{ "MANGOHUD": "1" }]` | MangoHud-Overlay aktivieren |
| `wineVersion` | GE-Proton-latest | Via protonup-qt installiert |
| `eacRuntime` | `true` | Easy Anti-Cheat Linux-Runtime |
| `autoInstallDxvk` | `true` | DXVK DirectX→Vulkan |
| `autoInstallDxvkNvapi` | `true` | NVAPI-Emulation (RTX-Features) |
| `autoInstallVkd3d` | `true` | VKD3D DirectX 12→Vulkan |
| `gamescope.enable` | `true` | Gamescope als Zwischenschicht (borderless, 2560x1440) |

---

## Verifikation

```bash
# i915 treibt Intel iGPU
lspci -nnk -d 8086:a780
# → Kernel driver in use: i915

# Nvidia-Treiber aktiv
lspci -nnk -d 10de:2206
# → Kernel driver in use: nvidia

# Nvidia-SMI
nvidia-smi
# → RTX 3080, Driver 595.58.03, CUDA 13.2

# VRAM-Nutzung während Rocket League
nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv
# → 4593, 1620 MiB, RocketLeague.exe
```

---

## Aktueller Stand & offene Punkte

**Funktioniert:**
- RTX 3080 wird für Rocket League genutzt (nvidia-smi bestätigt 1620 MB VRAM)
- Kein Absturz beim Fensterwechsel
- Heroic, GE-Proton, EAC Runtime aktiv
- i915 auf Intel UHD 770, PRIME-Offload konfiguriert

**Noch offen:**
- VK_SUBOPTIMAL_KHR tritt noch auf → kann zu Abstürzen führen
- MangoHud `Shift+F12` funktioniert nicht innerhalb von Gamescope
- Lag trotz Nvidia-GPU — PRIME-Copy-Overhead oder Gamescope-Overhead
- VM-Switching (libvirt GPU-Detach) noch nicht getestet

**Mögliche nächste Schritte:**
- `DXVK_CONFIG_FILE` mit `presenter.maxFrameLatency = 1` zum Testen
- `mangohud` als Gamescope-Argument (`--mangoapp`) statt Env-Var
- `nvtop` oder `gpu-top` für PRIME-Copy-Overhead-Messung
- `enableWineWayland = true` testen (Proton läuft dann direkt auf Wayland, kein X11-Bridge)
- `vm start` testen: prüfen ob libvirt GPU korrekt von `nvidia` → `vfio-pci` umhängt

---

## Alle Commits dieser Session

| Hash | Nachricht |
|---|---|
| `a24828e` | rocket league nativ + nvidia prime offload + heroic |
| `4ca35f0` | fix: nvidia ohne prime-block, niri kann igpu-drm-device öffnen |
| `0abc332` | nvme windows-partition als /mnt/nvme automount |
| `7a7738a` | fix: nvidia prime offload + i915.force_probe=a780 für niri-kompatibilität |
