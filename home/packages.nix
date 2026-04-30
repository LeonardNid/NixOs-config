{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # wl-clipboard
    keymapp
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
