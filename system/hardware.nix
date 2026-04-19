{ ... }:

{
  # Intel iGPU Treiber
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  # Erlaubt unprivilegierten Zugriff auf Hardware-PMU (intel_gpu_top ohne root)
  # i915 GPU PMU braucht system-weites Monitoring → paranoid=0 nötig
  boot.kernel.sysctl."kernel.perf_event_paranoid" = 0;

  # ZSA Keyboard (Voyager) Support
  hardware.keyboard.zsa.enable = true;
  users.groups.plugdev = {};
}
