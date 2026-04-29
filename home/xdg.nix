{ ... }:

{
  # Zen Browser: XDG file chooser portal aktivieren (für Drucken/Speichern-Dialog)
  home.file.".config/zen/vvityuaf.Default Profile/user.js".text = ''
    user_pref("widget.use-xdg-desktop-portal.file-picker", 2);
  '';

  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Browser
      "text/html"                = "zen.desktop";
      "x-scheme-handler/http"   = "zen.desktop";
      "x-scheme-handler/https"  = "zen.desktop";
      "x-scheme-handler/ftp"    = "zen.desktop";

      # PDF
      "application/pdf"         = "zen.desktop";

      # Videos
      "video/mp4"               = "mpv.desktop";
      "video/x-matroska"        = "mpv.desktop";
      "video/avi"               = "mpv.desktop";
      "video/webm"              = "mpv.desktop";
      "video/quicktime"         = "mpv.desktop";
      "video/ogg"               = "mpv.desktop";
      "video/mpeg"              = "mpv.desktop";
      "video/x-flv"             = "mpv.desktop";
      "video/3gpp"              = "mpv.desktop";

      # Audio
      "audio/mpeg"              = "mpv.desktop";
      "audio/ogg"               = "mpv.desktop";
      "audio/flac"              = "mpv.desktop";
      "audio/x-wav"             = "mpv.desktop";
      "audio/mp4"               = "mpv.desktop";
      "audio/opus"              = "mpv.desktop";

      # Bilder
      "image/jpeg"              = "imv.desktop";
      "image/png"               = "imv.desktop";
      "image/gif"               = "imv.desktop";
      "image/webp"              = "imv.desktop";
      "image/tiff"              = "imv.desktop";
      "image/bmp"               = "imv.desktop";
      "image/svg+xml"           = "imv.desktop";
      "image/avif"              = "imv.desktop";
      "image/heic"              = "imv.desktop";

      # Textdateien
      "text/plain"              = "org.kde.kate.desktop";
      "text/x-python"           = "org.kde.kate.desktop";
      "text/x-c"                = "org.kde.kate.desktop";
      "text/x-c++"              = "org.kde.kate.desktop";
      "text/x-shellscript"      = "org.kde.kate.desktop";
      "application/json"        = "org.kde.kate.desktop";
      "application/x-yaml"      = "org.kde.kate.desktop";
      "text/xml"                = "org.kde.kate.desktop";
      "text/csv"                = "org.kde.kate.desktop";

      # LibreOffice – Textdokumente
      "application/msword"                                                     = "libreoffice-writer.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "libreoffice-writer.desktop";
      "application/vnd.oasis.opendocument.text"                                = "libreoffice-writer.desktop";

      # LibreOffice – Tabellen
      "application/vnd.ms-excel"                                               = "libreoffice-calc.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"      = "libreoffice-calc.desktop";
      "application/vnd.oasis.opendocument.spreadsheet"                         = "libreoffice-calc.desktop";

      # LibreOffice – Präsentationen
      "application/vnd.ms-powerpoint"                                          = "libreoffice-impress.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "libreoffice-impress.desktop";
      "application/vnd.oasis.opendocument.presentation"                        = "libreoffice-impress.desktop";

      # Archive
      "application/zip"         = "org.kde.ark.desktop";
      "application/x-tar"       = "org.kde.ark.desktop";
      "application/gzip"        = "org.kde.ark.desktop";
      "application/x-bzip2"     = "org.kde.ark.desktop";
      "application/x-xz"        = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar"       = "org.kde.ark.desktop";
      "application/x-zstd"      = "org.kde.ark.desktop";
    };
  };
}
