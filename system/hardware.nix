{ ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "amdgpu" ];

# ZSA Keyboard (Voyager) Support
  hardware.keyboard.zsa.enable = true;
  users.groups.plugdev = {};
}
