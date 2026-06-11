{ pkgs, ... }:

{
  # --name sets the Wayland app_id to "Obsidian" instead of "electron"
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

  home.packages = with pkgs; [
    # --- CLI-Tools ---
    libnotify
    yazi
    helix
    broot
    ripgrep
    btop
    fzf
    fd
    bat
    wtype
    eza
    git-lfs
    jq
    zoxide
    glow
    gemini-cli
    wget
    nodejs

    # --- Browser ---
    (vivaldi.override { commandLineArgs = "--password-store=kwallet6 --ozone-platform=wayland --enable-features=WaylandWindowDecorations"; })
    firefox
    tor-browser

    # --- GUI-Apps ---
    vesktop
    signal-desktop
    zapzap
    obsidian
    kdePackages.okular
    obs-studio
    mpv
    vlc
    imv
    gimp
    drawing
    libreoffice-qt6-fresh
    file-roller
    easyeffects
    mission-center
    keymapp
  ];
}
