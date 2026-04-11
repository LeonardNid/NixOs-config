{ config, pkgs, ... }:

let
  controllerXml = pkgs.writeText "dualsense-hostdev.xml" ''
    <hostdev mode="subsystem" type="usb" managed="yes">
      <source>
        <vendor id="0x054c"/>
        <product id="0x0ce6"/>
      </source>
    </hostdev>
  '';

  vmFixconScript = pkgs.writeShellScript "vm-fixcon" ''
    VIRSH="${pkgs.libvirt}/bin/virsh"
    VM_NAME="windows11"

    if ! "$VIRSH" domstate "$VM_NAME" 2>/dev/null | grep -q running; then
      exit 0
    fi

    sleep 2
    "$VIRSH" detach-device "$VM_NAME" "${controllerXml}" 2>/dev/null || true
    sleep 1
    "$VIRSH" attach-device "$VM_NAME" "${controllerXml}"
  '';
in
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
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="0ce6", TAG+="systemd", ENV{SYSTEMD_WANTS}="vm-controller-reattach.service"
  '';

  programs.virt-manager.enable = true;

  # Auto-Reattach DualSense Controller bei USB-Reconnect
  systemd.services.vm-controller-reattach = {
    description = "Re-attach DualSense controller to Windows VM";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = vmFixconScript;
    };
  };

  # Firewall: Scream Audio (UDP 4010) von VM erlauben
  networking.firewall.allowedUDPPorts = [ 4010 ];
}
