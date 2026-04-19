{ ... }:

{
  # Intel iGPU Treiber
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  # Erlaubt unprivilegierten Zugriff auf Hardware-PMU (intel_gpu_top ohne root)
  boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;

  # ZSA Keyboard (Voyager) Support
  hardware.keyboard.zsa.enable = true;
  users.groups.plugdev = {};
}
