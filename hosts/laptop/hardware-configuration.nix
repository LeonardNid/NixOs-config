# WICHTIG: Diese Datei muss nach der Installation ERSETZT werden!
#
# Führe auf dem Laptop aus:
#   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# Oder nach einer Standardinstallation liegt sie unter /etc/nixos/hardware-configuration.nix
#
# Die UUIDs und Kernel-Module sind hardware-spezifisch und können hier
# nicht vorgegeben werden.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Typische Laptop-Kernel-Module (werden durch nixos-generate-config ersetzt)
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];  # oder "kvm-amd" für AMD-Laptop
  boot.extraModulePackages = [ ];

  # PLATZHALTER – nach der Installation ersetzen mit:
  #   sudo nixos-generate-config --show-hardware-config > hosts/laptop/hardware-configuration.nix
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Intel oder AMD Microcode – je nach CPU anpassen:
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
