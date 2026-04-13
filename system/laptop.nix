{ pkgs, lib, ... }:

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
  # GFXOFF deaktivieren – verhindert GPU-Wakeup-Delay bei KWin-Effekten
  boot.kernelParams = [ "amdgpu.gfxoff=0" ];
  # GPU-Performance: high auf AC (kein KWin-Delay), auto auf Akku (Stromsparen)
  services.tlp.settings = {
    RADEON_DPM_PERF_LEVEL_ON_AC = "high";
    RADEON_DPM_PERF_LEVEL_ON_BAT = "auto";
  };

  # Kanata: Hardening-Optionen die Device-Zugriff blockieren deaktivieren
  systemd.services.kanata-default.serviceConfig = {
    PrivateUsers = lib.mkForce false;
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "root";
  };

  # Home Row Mods via Kanata
  services.kanata = {
    enable = true;
    keyboards.default = {
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
      (defsrc
        a s d f j k l '
      )

      (deflayer default
        @a @s @d @f @j @k @l @ä
      )

      (defalias
        a  (tap-hold-release 200 150 a   lmet)
        s  (tap-hold-release 200 150 s   lalt)
        d  (tap-hold-release 200 150 d   lsft)
        f  (tap-hold-release 200 150 f   lctl)
        j  (tap-hold-release 200 150 j   rctl)
        k  (tap-hold-release 200 150 k   rsft)
        l  (tap-hold-release 200 150 l   ralt)
        ä  (tap-hold-release 200 150 '   rmet)
      )
    '';
    };
  };

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
