{ config, pkgs, ... }:

let
  vmToggleKbd = pkgs.python3.withPackages (ps: [ ps.evdev ]);
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
  # IOMMU aktivieren; GPU dynamisch per libvirt managed=yes an vfio-pci gebunden
  boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "random.trust_cpu=on" "i915.force_probe=a780" ];
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

  # Nach jedem Rebuild: Standard-Boot-Entry auf den gewünschten GPU-Modus setzen
  # (damit NixOS den default nicht auf die neue Generation zurücksetzt)
  boot.loader.systemd-boot.extraInstallCommands =
    let
      grep = "${pkgs.gnugrep}/bin/grep";
      sort  = "${pkgs.coreutils}/bin/sort";
      tail  = "${pkgs.coreutils}/bin/tail";
      sed   = "${pkgs.gnused}/bin/sed";
      ls    = "${pkgs.coreutils}/bin/ls";
      cat   = "${pkgs.coreutils}/bin/cat";
      bootctl = "${pkgs.systemd}/bin/bootctl";
    in ''
      MODE_FILE="/var/lib/gpu-switch-mode"
      if [ -f "$MODE_FILE" ] && [ "$(${cat} "$MODE_FILE")" = "vm" ]; then
        ENTRY=$(${ls} /boot/loader/entries/ 2>/dev/null | ${grep} "specialisation-gpuvm" | ${sort} -V | ${tail} -1 | ${sed} 's/\.conf$//')
        [ -n "$ENTRY" ] && ${bootctl} set-default "$ENTRY"
      else
        ENTRY=$(${ls} /boot/loader/entries/ 2>/dev/null | ${grep} -v specialisation | ${grep} "nixos-generation" | ${sort} -V | ${tail} -1 | ${sed} 's/\.conf$//')
        [ -n "$ENTRY" ] && ${bootctl} set-default "$ENTRY"
      fi
    '';

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
  boot.kernelModules = [ "kvmfr" "vfio" "vfio_iommu_type1" "vfio_pci" ];
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
    KERNEL=="event*", ATTRS{name}=="VMToggleKbd", SYMLINK+="input/vm-toggle-kbd", GROUP="kvm", MODE="0660", TAG+="uaccess"
    KERNEL=="event*", ATTRS{name}=="VirtualVoyager", SYMLINK+="input/virtual-voyager", GROUP="kvm", MODE="0660", TAG+="uaccess"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="0ce6", TAG+="systemd", ENV{SYSTEMD_WANTS}="vm-controller-reattach.service"
  '';

  programs.virt-manager.enable = true;

  # VM Toggle Keyboard Daemon (virtuelles uinput-Keyboard für QEMU grab-toggle)
  systemd.services.vm-toggle-kbd = {
    description = "VM Toggle Keyboard Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${vmToggleKbd}/bin/python3 ${../scripts/vm-toggle-kbd.py}";
    };
  };

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

  # OVMF binary patchen: "BOCHS " → "ALASKA", "BXPC" → "AMI "
  # qemu.ovmf.packages wurde in NixOS entfernt; OVMF kommt jetzt von QEMU selbst.
  # libvirt sysinfo überschreibt den Firmware-Vendor nicht — nur ein Binary-Patch wirkt.
  system.activationScripts.patchOvmf.text = ''
    mkdir -p /var/lib/libvirt/ovmf

    # CODE: aus QEMU kopieren und BOCHS-Strings patchen
    install -m644 ${pkgs.qemu}/share/qemu/edk2-x86_64-secure-code.fd \
      /var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd
    ${pkgs.python3}/bin/python3 -c "
f = '/var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd'
data = open(f, 'rb').read()
data = data.replace(b'BOCHS ', b'ALASKA')
data = data.replace(b'BXPC', b'AMI ')
open(f, 'wb').write(data)
"

    # VARS-Template: QEMU hat kein x86_64 vars-file, OVMFFull wird genutzt.
    # Nur beim ersten Mal kopieren — danach enthält die Datei VM-UEFI-Zustand.
    if [ ! -f /var/lib/libvirt/ovmf/OVMF_VARS.fd ]; then
      install -m644 ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd /var/lib/libvirt/ovmf/OVMF_VARS.fd
    fi
  '';
}
