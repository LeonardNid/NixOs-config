{ lib, ... }:

let
  # =============================================
  # DESKTOP WÄHLEN: "kde" oder "niri"
  # Danach: rebuild "switch to <desktop>"
  # =============================================
  desktop = "niri";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../system/nvidia.nix
    ../../vm/gpu-passthrough.nix
    ../../vm/libvirt-hooks.nix
    ../../system/corsair-mouse-daemon.nix
    ../../system/logitech-mouse-daemon.nix
    ../../system/amazonbasics-touchpad-daemon.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/audio.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")  ../../system/desktop.nix
  ++ lib.optional (desktop == "niri") ../../system/niri.nix;

  networking.hostName = "leonardn";

  # Windows-NVMe (ntfs3, Automount bei Zugriff, wird vor VM-Start unmounted)
  fileSystems."/mnt/nvme" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs3";
    options = [ "uid=1000" "gid=100" "umask=0022" "nofail" "noauto" "x-systemd.automount" ];
  };

  # HDD (ntfs3, für Backups und Medien)
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-uuid/01DB69DC8A91BC90";
    fsType = "ntfs3";
    options = [ "uid=1000" "gid=100" "umask=0022" "nofail" ];
  };

  # Desktop: auto-login (kein Passwort beim Booten)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";

  # Home-Module: desktop-spezifisch
  home-manager.users.leonardn = {
    _module.args.keyboardLayout = "neo";
    imports = [ ]
      ++ lib.optional (desktop == "niri") ../../home/desktop-niri.nix;
  };

  # GPU-Modus-Specialisation: bootet mit vfio-pci.ids → GPU sofort auf vfio-pci (kein Hot-Detach nötig)
  # Aktivierung: gpu-switch-reboot (nutzt bootctl set-oneshot auf diesen Entry)
  specialisation.gpuvm.configuration = {
    system.nixos.tags = [ "gpuvm" ];
    # Nur die VM-spezifischen Params hinzufügen – nicht mkForce, damit root=fstab/lsm=... erhalten bleiben
    boot.kernelParams = [
      "vfio-pci.ids=10de:2206,10de:1aef"
      "gpu_mode=vm"
    ];
    # GPU ist auf vfio-pci → nvidia hat kein Device → Intel iGPU übernimmt den Display
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;
  };
}
