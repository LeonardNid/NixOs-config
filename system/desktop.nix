{ ... }:

{
  services.xserver.enable = true;

  # KDE Plasma 6
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";

  # KWallet automatisch entsperren bei Login (PAM-Integration)
  security.pam.services.sddm.kwallet.enable = true;

  # Keyboard Layout
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  services.printing.enable = true;
}
