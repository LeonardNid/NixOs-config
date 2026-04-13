#!/usr/bin/env bash
# Bootstrap-Skript für frisches NixOS-Install auf dem Laptop
# Ausführen mit: bash <(curl -sL https://raw.githubusercontent.com/LeonardNid/NixOs-config/main/scripts/bootstrap.sh)
# oder nach manuellem Clone: bash ~/nixos-config/scripts/bootstrap.sh

set -e

REPO="https://github.com/LeonardNid/NixOs-config.git"
CONFIG_DIR="$HOME/nixos-config"
HOST="laptop"

echo "=== NixOS Bootstrap für $HOST ==="
echo ""

# 1. Config-Repo klonen (falls noch nicht vorhanden)
if [ ! -d "$CONFIG_DIR/.git" ]; then
  echo ">> Klone Config-Repo..."
  nix-shell -p git --run "git clone $REPO $CONFIG_DIR"
else
  echo ">> Config-Repo bereits vorhanden, überspringe Clone."
fi

# 2. Hardware-Konfiguration generieren
echo ""
echo ">> Generiere Hardware-Konfiguration..."
sudo nixos-generate-config --show-hardware-config > "$CONFIG_DIR/hosts/$HOST/hardware-configuration.nix"
echo "   Gespeichert: $CONFIG_DIR/hosts/$HOST/hardware-configuration.nix"

# 3. Rebuild
echo ""
echo ">> Starte nixos-rebuild switch --flake .#$HOST ..."
cd "$CONFIG_DIR"
sudo nixos-rebuild switch --flake ".#$HOST"

echo ""
echo "=== Fertig! ==="
echo ""
echo "Noch manuell erledigen:"
echo "  1. Vivaldi: Sync-Login + Als Standardbrowser bestätigen"
echo "  2. Vaultwarden-Extension: Einloggen & Hostseite auswählen"
echo "  3. claude authenticate"
