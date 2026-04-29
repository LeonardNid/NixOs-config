{ config, lib, ... }:

{
  # Nvidia proprietärer Treiber (RTX 3080) mit PRIME-Offload
  # iGPU (Intel UHD 770) treibt die Displays; Nvidia rendert per Offload
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" "modesetting" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId  = "PCI:0:2:0";   # Intel UHD 770  (00:02.0)
      nvidiaBusId = "PCI:1:0:0";   # RTX 3080       (01:00.0)
    };
  };
}
