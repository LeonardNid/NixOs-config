# KWin Latency Fix – AMD Renoir iGPU

## Problem

KDE Plasma 6 auf Wayland hatte ~1 Sekunde Delay vor dem Start bestimmter KWin-Effekte:
- Alt+Tab (Task Switcher)
- Super+W (Overview)
- Super+Tab

Andere Aktionen wie Super+D (Desktop anzeigen) oder Super+Pfeiltasten (Tiling) liefen sofort.

## Ursache

AMD Renoir APUs nutzen ein Feature namens **GFXOFF**: Der GPU-Core wird bei Inaktivität vollständig abgeschaltet. Wenn KWin einen compositor-basierten Effekt startet (der echtes GPU-Rendering braucht), muss die GPU erst aufwachen – das dauert 300–600ms.

Direkte WM-Aktionen (show desktop, tiling) brauchen kein GPU-Rendering und sind deshalb sofort.

Bestätigt durch:
```bash
echo "high" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level
```
→ Delay sofort weg.

Symptom im KWin-Log:
```
Libinput: event processing lagging behind by 503ms, your system is too slow
Could not delete texture because no context is current
```

## Fix

In `system/laptop.nix`:
```nix
boot.kernelParams = [ "amdgpu.gfxoff=0" ];
```

Deaktiviert GFXOFF dauerhaft für den amdgpu-Treiber. Die GPU bleibt aktiv und KWin-Effekte starten sofort.

**Trade-off:** Minimal höherer Stromverbrauch im Idle (~0.5–1W). Für Desktop-Nutzung irrelevant.

## Weitere KWin-Optimierungen (ebenfalls gesetzt)

In `~/.config/kwinrc` via plasma-manager oder kwriteconfig6:

```ini
[TabBox]
DelayTime=0          # Alt+Tab sofort zeigen (default: 90ms)

[Compositing]
HiddenPreviews=6     # Alle Fenstertexturen im VRAM halten (default: 5)
LatencyPolicy=Low    # Niedrige Compositing-Latenz priorisieren
```
