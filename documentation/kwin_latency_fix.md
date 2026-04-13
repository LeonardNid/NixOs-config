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

systemd.services.amdgpu-performance = {
  description = "Set AMD GPU to high performance (prevents KWin wakeup delay)";
  after = [ "multi-user.target" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "/bin/sh -c 'echo high > /sys/class/drm/card1/device/power_dpm_force_performance_level'";
  };
};
```

`amdgpu.gfxoff=0` deaktiviert GFXOFF im Kernel. Der systemd-Service setzt zusätzlich den Performance-Level auf `high` nach jedem Boot – beide zusammen verhindern den Delay zuverlässig.

**Trade-off:** Minimal höherer Stromverbrauch im Idle (~0.5–1W). Für Desktop-Nutzung irrelevant.

## Weitere KWin-Optimierungen (ebenfalls gesetzt)

In `home/laptop.nix` via home-manager activation (kwriteconfig6):

```ini
[KDE] (kdeglobals)
AnimationDurationFactor=0.5  # Animationen halbiert schnell

[TabBox] (kwinrc)
DelayTime=0                  # Alt+Tab sofort zeigen (default: 90ms)

[Compositing] (kwinrc)
LatencyPolicy=Low            # Niedrige Compositing-Latenz priorisieren
```
