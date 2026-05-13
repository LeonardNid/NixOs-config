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
    kdePackages.okular
    obs-studio
  ];


}
