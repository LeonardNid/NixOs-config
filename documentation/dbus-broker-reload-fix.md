# dbus-broker Reload-Fix — Rebuild hängt 90s + „Build fehlgeschlagen"

Behoben: 2026-06-10 (minipc, gilt aber für alle Hosts mit `services.dbus.implementation = "broker"`)

## Symptom

Bei **jedem** `rebuild` / `nixos-rebuild switch`:

```
reloading the following user units: dbus-broker.service
                                       ← hängt hier ~90 Sekunden
Failed to reload user unit dbus-broker.service
warning: the following user units failed: dbus-broker.service
warning: user activation for leonardn failed
...
returned non-zero exit status 4.
```

- Rebuild dauert 1,5 Minuten länger als nötig
- `rebuild`-Script meldet „✗ Build fehlgeschlagen!" und **überspringt den git push**
  (daher sammelten sich unpushte Commits an, `[⇡]` im Prompt)
- **Tatsächlich war der Switch jedes Mal erfolgreich** — Exit-Code 4 von
  `switch-to-configuration` heißt „aktiviert, aber mit Warnungen", nicht „fehlgeschlagen"

Journal (`journalctl --user -u dbus-broker.service`):

```
systemd[...]: Reloading D-Bus User Message Bus...
systemd[...]: dbus-broker.service: Reload operation timed out. Killing reload process.
systemd[...]: Reload failed for D-Bus User Message Bus.
```

## Ursache

Zwei Zutaten:

1. **NixOS triggert den Reload bei fast jedem Rebuild.** Das dbus-Modul
   ([nixos/modules/services/system/dbus.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/dbus.nix))
   setzt auf der **User**-Unit:
   ```nix
   systemd.user.services.dbus-broker = {
     reloadIfChanged = true;
     restartTriggers = [ configDir ];
   };
   ```
   `configDir` enthält u.a. die D-Bus-Service-Suchpfade des System-Profils — es ändert
   sich also bei praktisch jedem Rebuild (jedes neue/geänderte Paket) → Reload wird angefordert.

2. **Der Reload der User-Instanz deadlockt.** Der Reload läuft als D-Bus-Call
   (`ReloadConfig`) **über genau den Bus, der gerade reloaded wird**, während der
   User-systemd-Manager blockierend auf das Ende wartet. Bekannte Deadlock-Familie
   zwischen systemd und Message-Bus ([dbus-broker #121](https://github.com/bus1/dbus-broker/issues/121),
   [systemd #22552](https://github.com/systemd/systemd/pull/22552)).
   Nach 90 s (systemd-Default) wird der Reload-Prozess gekillt → „Reload failed".
   Der Bus selbst läuft dabei ununterbrochen weiter — es ist nie etwas kaputtgegangen.

## Fix 1: Reload-Trigger der User-Unit entfernen (`system/nix-settings.nix`)

```nix
systemd.user.services.dbus-broker.restartTriggers = lib.mkForce [ ];
```

Ohne Trigger ist die Unit über Rebuilds hinweg byte-identisch → `switch-to-configuration`
fasst sie nie wieder an. Verifizierbar: `X-Restart-Triggers` fehlt in der generierten Unit
(`nix eval --raw '.#nixosConfigurations.minipc.config.systemd.user.units."dbus-broker.service".text'`).

**Trade-off:** Neu installierte Pakete, die sich per D-Bus-Activation am **User**-Bus
registrieren („Telefonbuch-Eintrag": Dienst X anrufen → Programm Y starten), werden erst
nach dem nächsten **Re-Login** aktivierbar. Betrifft nur diesen Sonderfall — normale
Programmstarts, Config-Änderungen, Updates: alles sofort wie gewohnt. Der System-Bus
reloaded weiterhin normal.

## Fix 2: `rebuild`-Script unterscheidet Warnung von Fehlschlag (`home/scripts.nix`)

Vor dem Switch wird `readlink -f /run/current-system` gemerkt. Meldet `nixos-rebuild`
einen Fehler, prüft das Script, ob die Generation **trotzdem gewechselt** hat:

- Generation gewechselt → gelbe Box **„⚠ Aktiviert, aber mit Warnungen"** →
  Noctalia-Sync + **git push laufen normal weiter**
- Generation unverändert → rote Box „✗ Build fehlgeschlagen!" + Abbruch (wie bisher)

Damit kostet keine zukünftige harmlose Aktivierungs-Warnung mehr den Push.

## Hinweis für die Zukunft

Sollte `services.dbus.implementation` je wieder auf `"dbus"` zurückgestellt werden:
Der Wechsel broker→dbus hat eine eigene bekannte Stall-Falle beim Umschalten
([nixpkgs #428577](https://github.com/NixOS/nixpkgs/issues/428577)) — dann besser
`nixos-rebuild boot` + Reboot statt `switch`. Außerdem den `mkForce`-Override entfernen,
er gehört zur broker-Implementierung.
