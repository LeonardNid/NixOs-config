{ ... }:

{
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
