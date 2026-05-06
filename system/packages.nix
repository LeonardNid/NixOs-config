{ pkgs, ... }:

{
  programs.firefox.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  environment.systemPackages = with pkgs; [
    borgbackup
    wget
    nodejs
    vesktop
    (vivaldi.override { commandLineArgs = "--password-store=kwallet6 --ozone-platform=wayland --enable-features=WaylandWindowDecorations"; })
    tailscale
    easyeffects
    obsidian
    zapzap
    mpv
    vlc
    imv
    file-roller
    drawing
    # gimp
    libreoffice-qt6-fresh
    gemini-cli
    # qutebrowser
    mission-center
    signal-desktop
    # rustdesk-flutter
  ];

  # Obsidian: --name setzt den Wayland app_id korrekt auf "Obsidian" statt "electron"
  home.file.".local/share/applications/obsidian.desktop".text = ''
    [Desktop Entry]
    Name=Obsidian
    Exec=obsidian --name Obsidian %u
    Icon=obsidian
    Type=Application
    Categories=Office
    MimeType=x-scheme-handler/obsidian
    StartupWMClass=Obsidian
    Comment=A powerful knowledge base
  '';
}
