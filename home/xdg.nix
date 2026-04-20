{ ... }:

{
  # Zen Browser: XDG file chooser portal aktivieren (für Drucken/Speichern-Dialog)
  home.file.".config/zen/vvityuaf.Default Profile/user.js".text = ''
    user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
  '';

  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf"        = "zen.desktop";
      "text/html"             = "zen.desktop";
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/ftp"  = "zen.desktop";
    };
  };
}
