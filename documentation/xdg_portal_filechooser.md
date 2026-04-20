# XDG Portal – Dateidialoge unter Niri

## Problem

Browser-Druckdialog: Klick auf "Speichern" macht nichts.

## Ursachen & Fixes

### 1. GNOME-Portal blockiert FileChooser ohne Fallback

`xdg-desktop-portal` 1.20.x fällt bei `default = ["gnome" "gtk"]` **nicht** auf GTK zurück wenn GNOME fehlschlägt. GNOME-Portal braucht Nautilus für FileChooser – ohne Nautilus schlägt es still fehl.

Diagnose: `journalctl --user | grep -i portal` zeigt:
```
xdg-desktop-portal-gnome: Delegated FileChooser call failed: The name org.gnome.Nautilus was not provided
```

**Fix** in `system/niri.nix`: GTK als Default, GNOME nur für Screencasting:
```nix
xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
xdg.portal.config.niri = {
  default = [ "gtk" ];
  "org.freedesktop.impl.portal.ScreenCast"    = [ "gnome" ];
  "org.freedesktop.impl.portal.Screenshot"    = [ "gnome" ];
  "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
};
```

### 2. Vivaldi läuft unter XWayland

Ohne `--ozone-platform=wayland` öffnet Vivaldi Dateidialoge über XWayland – funktioniert nicht auf reiner Wayland-Session.

**Fix** in `system/packages.nix`:
```nix
(vivaldi.override { commandLineArgs = "--password-store=kwallet6 --ozone-platform=wayland --enable-features=WaylandWindowDecorations"; })
```

### 3. Zen Browser nutzt Portal nicht automatisch

**Fix** via `home/xdg.nix` (`user.js` ins Profil schreiben):
```
user_pref("widget.use-xdg-desktop-portal.file-picker", 2);
```
Wert `2` = erzwungen, `1` = nur wenn verfügbar.

## Nach Änderungen

Portal-Dienste neu starten (kein Reboot nötig):
```bash
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome
```
