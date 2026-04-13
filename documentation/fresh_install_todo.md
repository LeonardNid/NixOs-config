# Fresh Install Guide - Laptop

## 1. Config-Repo klonen

```bash
nix-shell -p git --run "git clone https://github.com/LeonardNid/NixOs-config.git ~/nixos-config"
bash ~/nixos-config/scripts/bootstrap.sh
```

Das Skript erledigt automatisch:
- Hardware-Konfiguration generieren (`nixos-generate-config`)
- `nixos-rebuild switch --flake .#laptop`

---

## 2. SSH-Key für GitHub einrichten

Damit `rebuild` (inkl. `git push`) funktioniert:

```bash
ssh-keygen -t ed25519 -C "niedens03@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

Den Key auf https://github.com/settings/keys hinterlegen, dann testen:

```bash
ssh -T git@github.com
# → Hi LeonardNid! You've successfully authenticated...
```

Remote auf SSH umstellen:

```bash
git -C ~/nixos-config remote set-url origin git@github.com:LeonardNid/NixOs-config.git
```

---

## 3. Manuell (nicht automatisierbar)

- [ ] Vivaldi: Sync-Login (Einstellungen → Sync)
- [ ] Vaultwarden-Extension: Einloggen & Hostseite auswählen
- [ ] `claude authenticate`
- [ ] Nextcloud: Account einrichten (einmalig – danach startet es automatisch im Hintergrund)

---

## Danach

Das `rebuild`-Skript ist im PATH und übernimmt alle zukünftigen Updates:

```bash
rebuild "meine änderung"
```
