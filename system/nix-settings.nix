{ lib, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings = {
    trusted-users = [ "root" "leonardn" ];
    substituters = [
      "https://claude-code.cachix.org"
      "https://niri.cachix.org"
      "https://noctalia.cachix.org"
    ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;

  services.dbus.implementation = "broker";

  # Kein Reload der dbus-broker USER-Unit bei nixos-rebuild switch: Der Reload
  # (D-Bus-Call über den Bus, der gerade reloaded wird) deadlockt und läuft in
  # einen 90s-Timeout → jeder Rebuild hängt + endet mit Exit 4 ("mit Warnungen").
  # Trade-off: neue D-Bus-Activation-Einträge erreichen den User-Bus erst nach
  # Re-Login. System-Bus reloaded weiterhin normal.
  systemd.user.services.dbus-broker.restartTriggers = lib.mkForce [ ];

  # Proton/Wine benötigt sehr viele Memory Mappings (DLLs, Shader-Cache, etc.)
  # Standard 65536 oder 1M reicht nicht → Spiele frieren ein wenn das Limit erreicht wird
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
