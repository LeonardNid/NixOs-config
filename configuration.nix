# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, self, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Intel iGPU Treiber
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  # IOMMU und GPU Passthrough
  boot.kernelParams = [ "intel_iommu=on,sm_on" "iommu=pt" "vfio-pci.ids=10de:2206,10de:1aef" "random.trust_cpu=on" ];
  boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

  # Virtualisierung
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    qemu.verbatimConfig = let
      eventDevices = builtins.genList (i: ''"/dev/input/event${toString i}"'') 261;
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
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="3297", ATTRS{idProduct}=="1977", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="input", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", GROUP="kvm", MODE="0660"
    KERNEL=="event*", ATTRS{idVendor}=="3297", ATTRS{idProduct}=="1977", SYMLINK+="input/voyager-kbd", TAG+="uaccess"
    KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", ENV{ID_INPUT_MOUSE}=="1", SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=50", TAG+="uaccess"
    KERNEL=="event*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", ENV{ID_INPUT_MOUSE}=="1", SYMLINK+="input/vm-mouse", OPTIONS+="link_priority=100", TAG+="uaccess"
  '';

  programs.virt-manager.enable = true;

  # Corsair Maus/Tastatur Support (Open-Source iCUE Alternative)
  hardware.ckb-next.enable = true;

  # ZSA Keyboard (Voyager) Support
  hardware.keyboard.zsa.enable = true;
  users.groups.plugdev = {};


  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings = {
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };



  networking.hostName = "leonardn";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Passwordless sudo für leonardn
  security.sudo.extraRules = [{
    users = [ "leonardn" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.leonardn = {
    isNormalUser = true;
    description = "Leonard Niedens";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "plugdev" ];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  users.users.leonardn.shell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    nodejs
    discord
    vivaldi
    tailscale
    easyeffects
    obsidian
    nextcloud-client
    zapzap
  ];

  services.tailscale.enable = true;

   environment.sessionVariables = {
     DEFAULT_BROWSER = "vivaldi-stable";
     BROWSER = "vivaldi-stable";
   };


  environment.shellAliases = {
    gemini = "npx @google/gemini-cli";
  };



  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Firewall: Scream Audio (UDP 4010) von VM erlauben
  networking.firewall.allowedUDPPorts = [ 4010 ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  # Build-Name im Boot-Menü (zeigt den Git-Commit-Hash)
  system.configurationRevision = self.rev or "dirty";
  system.nixos.label = "git-${self.shortRev or "dirty"}";

}
