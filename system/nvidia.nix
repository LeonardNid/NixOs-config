{ config, lib, ... }:

{
  # Nvidia proprietärer Treiber (RTX 3080)
  # Display läuft auf Intel iGPU; Nvidia für Rendering via Runtime-Env-Vars:
  # __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    # Kein prime-Block: NixOS-PRIME-udev-Regeln blockieren Niri vom Intel-DRM-Device
  };
}
