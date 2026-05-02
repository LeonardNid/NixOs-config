{ ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings = {
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  services.dbus.implementation = "broker";

  # Proton/Wine benötigt sehr viele Memory Mappings (DLLs, Shader-Cache, etc.)
  # Standard 65536 oder 1M reicht nicht → Spiele frieren ein wenn das Limit erreicht wird
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
