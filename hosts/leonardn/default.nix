{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../system/gpu-passthrough.nix
    ../../system/corsair-scroll-fix.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/desktop.nix
    ../../system/audio.nix
    ../../system/users.nix
    ../../system/packages.nix
  ];
}
