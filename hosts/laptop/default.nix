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

  networking.hostName = "laptop";

  # Laptop-spezifische Home-Manager-Module (Touchpad, Nextcloud, etc.)
  home-manager.users.leonardn = { imports = [ ../../home/laptop.nix ]; };
}
