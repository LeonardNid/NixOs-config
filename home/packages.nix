{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wl-clipboard
    keymapp
    libnotify
  ];

  # Obsidian nativ unter Wayland starten – verhindert "electron"-Anzeige in der Taskleiste
  xdg.desktopEntries.obsidian = {
    name = "Obsidian";
    exec = "obsidian --ozone-platform=wayland %u";
    icon = "obsidian";
    categories = [ "Office" ];
    mimeType = [ "x-scheme-handler/obsidian" ];
    comment = "A powerful knowledge base";
  };
}
