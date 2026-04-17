{ lib, ... }:

let
  # =============================================
  # DESKTOP WÄHLEN: "kde" oder "hyprland"
  # Danach: rebuild "switch to <desktop>"
  # =============================================
  desktop = "hyprland";
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
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")      ../../system/desktop.nix
  ++ lib.optional (desktop == "hyprland") ../../system/hyprland.nix;

  networking.hostName = "laptop";

  # Home-Module: gemeinsam + desktop-spezifisch
  home-manager.users.leonardn = {
    imports = [ ../../home/nextcloud.nix ]   # immer: Nextcloud
      ++ lib.optional (desktop == "kde")      ../../home/laptop-kde.nix
      ++ lib.optional (desktop == "hyprland") ../../home/laptop-hyprland.nix;
  };
}
