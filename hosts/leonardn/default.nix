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

  # AmazonBasics Touchpad (USB, 248a:8278):
  # - Mouse-Interface (interface 00) in eigene libinput-Gruppe → BTN_LEFT/RIGHT von event6 werden verarbeitet
  # - Touchpad-Interface (interface 01) als external markieren
  services.udev.extraRules = ''
    ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8278", SUBSYSTEM=="input", ENV{ID_USB_INTERFACE_NUM}=="00", ENV{LIBINPUT_DEVICE_GROUP}="amazon-touchpad-mouse"
    ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8278", SUBSYSTEM=="input", ENV{ID_USB_INTERFACE_NUM}=="01", ENV{LIBINPUT_DEVICE_GROUP}="amazon-touchpad-surface", ENV{ID_INPUT_TOUCHPAD_INTEGRATION}="external"
  '';

  # Libinput-Quirk: INPUT_PROP_BUTTONPAD deaktivieren.
  # Der Kernel-Treiber markiert das Touchpad fälschlicherweise als Clickpad (BUTTONPAD),
  # wodurch libinput absichtlich alle Button-Klicks ohne Touch-Daten ignoriert.
  # Ohne diesen Fix funktionieren die physischen Tasten nicht.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [AmazonBasics Touchpad physical buttons fix]
    MatchBus=usb
    MatchVendor=0x248A
    MatchProduct=0x8278
    AttrInputPropDisable=INPUT_PROP_BUTTONPAD
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
