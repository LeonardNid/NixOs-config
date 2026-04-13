{ pkgs, ... }:

{
  # Power Management mit TLP
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Akku-Ladesteuerung (für Akkugesundheit bei häufigem Netzbetrieb)
      # START_CHARGE_THRESH_BAT0 = 20;
      # STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Verhindert Konflikte mit TLP
  services.power-profiles-daemon.enable = false;

  boot.kernelModules = [ "uinput" ];

  # AMD Renoir: GFXOFF deaktivieren + GPU auf performance halten
  # Verhindert ~1s Wakeup-Delay bei KWin-Effekten (Alt+Tab, Overview etc.)
  boot.kernelParams = [ "amdgpu.gfxoff=0" ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", \
      ATTR{device/power_dpm_force_performance_level}="high"
  '';

  # Touchpad
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      middleEmulation = true;
    };
  };

  # Bildschirmhelligkeit per Benutzer steuerbar
  hardware.brillo.enable = true;

  # Suspend/Hibernate bei Akkuschwäche
  services.upower = {
    enable = true;
    criticalPowerAction = "HybridSleep";
  };

  # Laptop-typische Pakete
  environment.systemPackages = with pkgs; [
    brightnessctl
    powertop
    acpi
  ];
}
