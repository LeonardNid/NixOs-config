{ config, ... }:

{
  # IOMMU und GPU Passthrough (statisch an vfio-pci gebunden)
  boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "vfio-pci.ids=10de:2206,10de:1aef" "random.trust_cpu=on" ];
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

  # Virtualisierung
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    onBoot = "ignore";
    qemu.verbatimConfig = let
      eventDevices = builtins.genList (i: ''"/dev/input/event${toString i}"'') 300;
    in ''
      cgroup_device_acl = [
        "/dev/null", "/dev/full", "/dev/zero",
        "/dev/random", "/dev/urandom",
        "/dev/ptmx", "/dev/userfaultfd",
        "/dev/kvmfr0",
        ${builtins.concatStringsSep ",\n        " eventDevices}
      ]
    '';
  };

  # Looking Glass (KVMFR Kernel Modul für shared memory)
  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
  boot.kernelModules = [ "kvmfr" ];
  boot.extraModprobeConfig = ''
    options kvmfr static_size_mb=128
  '';

  # udev Rules für Input-Devices und KVMFR
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="3297", ATTRS{idProduct}=="1977", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", GROUP="kvm", MODE="0660"
    KERNEL=="event*", ATTRS{idVendor}=="3297", ATTRS{idProduct}=="1977", SYMLINK+="input/voyager-kbd", TAG+="uaccess"
    KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", ENV{ID_INPUT_MOUSE}=="1", SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=50", TAG+="uaccess"
    KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", ENV{ID_INPUT_MOUSE}=="1", SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=100", TAG+="uaccess"
    KERNEL=="event*", ATTRS{name}=="CorsairFixed", SYMLINK+="input/corsair-fixed", GROUP="kvm", MODE="0666", TAG+="uaccess"
  '';

  programs.virt-manager.enable = true;

  # Firewall: Scream Audio (UDP 4010) von VM erlauben
  networking.firewall.allowedUDPPorts = [ 4010 ];
}
