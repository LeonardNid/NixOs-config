{ ... }:

{
  # Intel iGPU Treiber
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  # ZSA Keyboard (Voyager) Support
  hardware.keyboard.zsa.enable = true;
  users.groups.plugdev = {};
}
