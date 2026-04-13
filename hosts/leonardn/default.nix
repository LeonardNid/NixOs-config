{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../vm/gpu-passthrough.nix
    ../../system/corsair-mouse-daemon.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/desktop.nix
    ../../system/audio.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ];

  networking.hostName = "leonardn";

  # Desktop: auto-login (kein Passwort beim Booten)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";
}
