{ lib, ... }:

let
  # =============================================
  # DESKTOP WÄHLEN: "kde" oder "niri"
  # Danach: rebuild "switch to <desktop>"
  # =============================================
  desktop = "niri";
in
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
    ../../system/audio.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")  ../../system/desktop.nix
  ++ lib.optional (desktop == "niri") ../../system/niri.nix;

  networking.hostName = "leonardn";

  # AmazonBasics Touchpad: Mouse-Interface (event6) in eigene libinput-Gruppe,
  # damit die physischen Tasten unabhängig vom Touchpad-Interface verarbeitet werden.
  # Ohne das ignoriert libinput event6's BTN_LEFT/BTN_RIGHT (beide in group9).
  services.udev.extraRules = ''
    ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8278", SUBSYSTEM=="input", ENV{ID_USB_INTERFACE_NUM}=="00", ENV{LIBINPUT_DEVICE_GROUP}="amazon-touchpad-mouse"
    ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8278", SUBSYSTEM=="input", ENV{ID_USB_INTERFACE_NUM}=="01", ENV{LIBINPUT_DEVICE_GROUP}="amazon-touchpad-surface"
  '';

  # Desktop: auto-login (kein Passwort beim Booten)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";

  # Home-Module: desktop-spezifisch
  home-manager.users.leonardn = {
    imports = [ ]
      ++ lib.optional (desktop == "niri") ../../home/desktop-niri.nix;
  };
}
