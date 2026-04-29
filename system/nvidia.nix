{ config, lib, ... }:

{
  # Nvidia proprietärer Treiber (RTX 3080) mit PRIME-Offload
  # i915.force_probe=a780 (in gpu-passthrough.nix) sorgt dafür, dass i915 die
  # Intel UHD 770 vor simpledrm beansprucht → Niri kann das DRM-Device öffnen
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId  = "PCI:0:2:0";   # Intel UHD 770  (00:02.0)
      nvidiaBusId = "PCI:1:0:0";   # RTX 3080       (01:00.0)
    };
  };
}
