# Mini-PC: UMA-Buffer (iGPU-VRAM) — nur 9,5 GiB RAM sichtbar

Erstellt: 2026-06-09

## Problem

Das GMKtec Nucbox M6 Ultra hat **16 GiB physischen RAM verbaut**, aber unter Linux (und im BIOS)
sind nur ~9,5 GiB nutzbar. Kernel und OS sehen den Rest gar nicht.

```
$ free -h
Speicher: 9,5Gi
```

## Ursache

Das BIOS reserviert einen statischen **UMA Frame Buffer** für die integrierte Radeon 760M iGPU.
Dieser Block ist für den OS-Kernel komplett unsichtbar — er taucht nicht einmal in der e820-Memory-Map auf.

Größe laut `amdgpu`-Treiber:
```
amdgpu: VRAM: 6144M  (= 6 GiB, fest reserviert)
amdgpu: GTT:  4870M  (= dynamisch aus System-RAM, bei Bedarf)
```

Das BIOS versteckt also **6 GiB** für die GPU, obwohl die GPU zusätzlich noch ~5 GiB dynamisch
(GTT) aus dem System-RAM ziehen kann. Der statische Buffer bringt bei normaler Desktop-Nutzung
daher kaum Vorteil.

## Fix: UMA-Buffer im BIOS verkleinern

> **Erledigt (2026-06-09):** Auf `2G` gesetzt → `free -h` zeigt jetzt ~13 GiB.

1. Reboot → beim Start **`Entf`** oder **`F2`** für das BIOS-Setup
2. Navigieren zu:
   ```
   Advanced → AMD CBS → GFX Configuration → UMA Frame Buffer Size
   ```
   (Genaue Bezeichnung kann je nach BIOS-Version leicht abweichen)
3. Wert von `6G` (Werkseinstellung) auf z. B. **`2G`** oder **`512M`** setzen
4. Speichern & Reboot

### Erwartetes Ergebnis nach Änderung

| UMA-Einstellung | Sichtbarer RAM | GPU-VRAM (statisch) | GTT (dynamisch) |
|---|---|---|---|
| `6G` (Werk) | ~9,5 GiB | 6 GiB | ~5 GiB |
| `2G` | ~13,5 GiB | 2 GiB | ~5 GiB |
| `512M` | ~15 GiB | 512 MiB | ~5 GiB |

Die GPU-Performance für normalen Desktop-Betrieb ändert sich nicht spürbar, da Wayland/amdgpu
den GTT-Speicher dynamisch nutzt.

## Diagnose-Befehle

```bash
# Sichtbarer RAM
free -h

# GPU-VRAM-Größe (zeigt den UMA-Buffer)
cat /sys/class/drm/card*/device/mem_info_vram_total

# Kernel-Log (VRAM + GTT)
dmesg | grep -i "amdgpu.*vram\|amdgpu.*gtt"
```
