{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../system/laptop.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/desktop.nix
    ../../system/audio.nix
    ../../system/users.nix
    ../../system/packages.nix
  ];

  # Laptop-spezifischer Hostname
  networking.hostName = "laptop";
}
