# Fresh Install - Laptop

## Automatisch (Bootstrap-Skript)

```bash
nix-shell -p git --run "git clone https://github.com/LeonardNid/NixOs-config.git ~/nixos-config"
bash ~/nixos-config/scripts/bootstrap.sh
```

Das Skript erledigt:
- Hardware-Konfiguration generieren
- `nixos-rebuild switch --flake .#laptop`

## Manuell danach

- [ ] Vivaldi: Sync-Login (Einstellungen → Sync)
- [ ] Vivaldi: Als Standardbrowser bestätigen (falls nötig)
- [ ] Vaultwarden-Extension: Einloggen & Hostseite auswählen
- [ ] `claude authenticate`
