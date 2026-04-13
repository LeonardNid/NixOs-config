# Home Row Mods – Kanata Setup

## Layout

| Taste | Tap | Hold |
|-------|-----|------|
| `A`   | a   | Super (links) |
| `S`   | s   | Alt (links) |
| `D`   | d   | Shift (links) |
| `F`   | f   | Ctrl (links) |
| `J`   | j   | Ctrl (rechts) |
| `K`   | k   | Shift (rechts) |
| `L`   | l   | Alt (rechts) |
| `Ä`   | ä   | Super (rechts) |

`Ä` liegt physisch auf der US-`'`-Position (KEY_APOSTROPHE) – Kanata arbeitet mit Rohkeycodes unabhängig vom Tastaturlayout.

## Konfiguration (`system/laptop.nix`)

```nix
systemd.services.kanata-default.serviceConfig = {
  PrivateUsers = lib.mkForce false;
  DynamicUser = lib.mkForce false;
  User = lib.mkForce "root";
};

services.kanata = {
  enable = true;
  keyboards.default = {
    devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
    extraDefCfg = "process-unmapped-keys yes";
    config = ''
      (defsrc
        a s d f j k l '
      )
      (deflayer default
        @a @s @d @f @j @k @l @ä
      )
      (defalias
        a  (tap-hold-release 200 150 a   lmet)
        s  (tap-hold-release 200 150 s   lalt)
        d  (tap-hold-release 200 150 d   lsft)
        f  (tap-hold-release 200 150 f   lctl)
        j  (tap-hold-release 200 150 j   rctl)
        k  (tap-hold-release 200 150 k   rsft)
        l  (tap-hold-release 200 150 l   ralt)
        ä  (tap-hold-release 200 150 '   rmet)
      )
    '';
  };
};
```

## Timing

- **tap-timeout: 200ms** – Taste kürzer als 200ms gedrückt → Buchstabe
- **hold-timeout: 150ms** – Taste länger als 150ms gedrückt → Modifier

Anpassen falls nötig: höherer tap-timeout = weniger versehentliche Modifier, aber langsamerer Hold-Response.

## Problemlösungen

### Permission denied beim Start
Der NixOS-Kanata-Service läuft standardmäßig mit `DynamicUser=true` und `PrivateUsers=true` (Hardening), was den Zugriff auf `/dev/input/*` und `/dev/uinput` blockiert – auch wenn der User in den Gruppen `input` und `uinput` ist.

Fix: Service-Hardening per `systemd.services.kanata-default.serviceConfig` überschreiben und als `root` ausführen.

### Keyboard-Device angeben
Kanata braucht einen expliziten Device-Pfad, sonst schlägt die Erkennung fehl:
```
/dev/input/by-path/platform-i8042-serio-0-event-kbd
```

### Roll-Reihenfolge falsch (z.B. "komm" → "okmm")
Ohne `process-unmapped-keys yes` puffert Kanata die Home-Row-Taste und lässt nicht-gemappte Tasten sofort durch → falsche Ausgabe-Reihenfolge bei schnellem Tippen.

Fix via `extraDefCfg = "process-unmapped-keys yes"` – das NixOS-Modul merged das in den auto-generierten `defcfg`-Block. Kein eigener `(defcfg ...)`-Block im `config`-String nötig (würde Konflikte erzeugen).

### NixOS-Modul: defcfg nicht direkt in config schreiben
Das NixOS-Kanata-Modul generiert selbst einen `defcfg`-Block (mit `linux-dev` aus `devices` und `linux-continue-if-no-devs-found yes`). Eigener `defcfg`-Block im `config`-String führt zu Build-Fehler. Stattdessen `extraDefCfg` verwenden.
