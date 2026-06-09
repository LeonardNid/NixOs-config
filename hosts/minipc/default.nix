{ lib, pkgs, ... }:

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
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/audio.nix
    ../../system/bluetooth.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")  ../../system/desktop.nix
  ++ lib.optional (desktop == "niri") ../../system/niri.nix;

  networking.hostName = "minipc";

  # ── Moonlight-Streaming: Direktverbindung zum Gaming-PC über enp3s0 ──
  # eno1 = Internet (Router), enp3s0 = Direktkabel zum Gaming-PC.
  # NetworkManager darf enp3s0 NICHT verwalten, sonst greift die statische IP nicht.
  networking.networkmanager.unmanaged = [ "interface-name:enp3s0" ];

  # Statische IP auf dem Direktlink (Gaming-PC bekommt 10.0.0.1).
  networking.interfaces.enp3s0.ipv4.addresses = [{
    address = "10.0.0.2";
    prefixLength = 30;
  }];

  # Wake-on-LAN auf dem LAN-Interface (eno1, MAC 84:47:09:86:FF:C2).
  # Setzt beim Boot via ethtool das WoL-Magic-Packet-Flag ("g").
  # Senden vom anderen Rechner: `wakeonlan 84:47:09:86:FF:C2`.
  # Voraussetzung: im BIOS „Wake on LAN" / „Power On by PCI-E" aktivieren.
  networking.interfaces.eno1.wakeOnLan.enable = true;

  # Internet-Sharing: eno1 (Router) → enp3s0 (Gaming-PC) via NAT
  networking.nat = {
    enable = true;
    externalInterface = "eno1";
    internalInterfaces = [ "enp3s0" ];
  };

  # Desktop: auto-login (kein Passwort beim Booten)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";

  # Home-Module: desktop-spezifisch
  home-manager.users.leonardn = {
    _module.args.keyboardLayout = "neo";
    _module.args.vmTools = false;  # kein VM/Looking-Glass/scream auf dem Mini-PC (Moonlight statt VM)
    imports = [ ]
      ++ lib.optional (desktop == "niri") ../../home/desktop-niri.nix;
    home.packages = [ pkgs.moonlight-qt ];   # Moonlight-Client (Stream-Empfänger)

    # Moonlight-Icon für Noctalia: quickshell durchsucht nur ~/.local/share/icons/hicolor,
    # nicht das Profil-hicolor → Icon dorthin spiegeln (gleiches Muster wie chromium/scream).
    home.file.".local/share/icons/hicolor/scalable/apps/moonlight.svg".source =
      "${pkgs.moonlight-qt}/share/icons/hicolor/scalable/apps/moonlight.svg";
  };
}
