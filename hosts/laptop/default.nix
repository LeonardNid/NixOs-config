{ lib, ... }:

let
  # =============================================
  # DESKTOP WÄHLEN: "kde", "hyprland", "mango" oder "niri"
  # Danach: rebuild "switch to <desktop>"
  # =============================================
  desktop = "niri";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../system/laptop.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/audio.nix
    ../../system/bluetooth.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")      ../../system/desktop.nix
  ++ lib.optional (desktop == "hyprland") ../../system/hyprland.nix
  ++ lib.optional (desktop == "mango")    ../../system/mango.nix
  ++ lib.optional (desktop == "niri")     ../../system/niri.nix;

  networking.hostName = "laptop";

  networking.interfaces.enp2s0.ipv4.addresses = [{
    address = "10.0.0.2";
    prefixLength = 30;
  }];

  networking.nat = {
    enable = true;
    externalInterface = "wlp3s0";
    internalInterfaces = [ "enp2s0" ];
  };

  # Home-Module: gemeinsam + desktop-spezifisch
  home-manager.users.leonardn = {
    _module.args.keyboardLayout = "qwertz";
    imports = [ ../../home/nextcloud.nix ]   # immer: Nextcloud
      ++ lib.optional (desktop == "kde")      ../../home/laptop-kde.nix
      ++ lib.optional (desktop == "hyprland") ../../home/laptop-hyprland.nix
      ++ lib.optional (desktop == "mango")    ../../home/laptop-mango.nix
      ++ lib.optional (desktop == "niri")     ../../home/laptop-niri.nix;
  };
}
