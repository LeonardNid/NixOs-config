{ ... }:

{
  services.xserver.enable = true;

  # KDE Plasma 6
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Keyboard Layout
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  services.printing.enable = true;
}
