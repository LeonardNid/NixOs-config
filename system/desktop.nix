{ pkgs, ... }:

{
  services.xserver.enable = true;

  # KDE Plasma 6
  services.displayManager.sddm = {
    enable = true;
    theme = "catppuccin-sddm-corners";
  };
  environment.systemPackages = [ pkgs.catppuccin-sddm-corners ];
  services.desktopManager.plasma6.enable = true;

  # Keyboard Layout
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  services.printing.enable = true;
}
