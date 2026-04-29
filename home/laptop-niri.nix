{ pkgs, ... }:

let
  wallpaper = "/home/leonardn/nixos-config/wallpapers/surreal-underwater-3840x2160-26042.jpg";
in
{
  # Niri Window Manager — Original Niri Experience
  programs.niri.config = ''
    input {
      keyboard {
        xkb { layout "de"; }
        repeat-delay 350
        repeat-rate 25
        numlock
      }
      touchpad {
        tap
        natural-scroll
      }
      focus-follows-mouse max-scroll-amount="25%"
    }

    layout {
      gaps 8
      center-focused-column "never"
      preset-column-widths {
        proportion 0.333
        proportion 0.5
        proportion 0.667
      }
      default-column-width { proportion 0.5; }
      focus-ring {
        width 4
        active-color "#89b4fa"
        inactive-color "#585b70"
      }
      border {
        off
        width 4
        active-color "#89b4fa"
        inactive-color "#585b70"
      }
    }

    // Autostart
    spawn-at-startup "noctalia-shell"
    spawn-at-startup "swaybg" "-i" "${wallpaper}" "-m" "fill"
    spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
    spawn-at-startup "nm-applet" "--indicator"

    // Hotkey-Overlay beim Start nicht anzeigen
    hotkey-overlay {
      skip-at-startup
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    cursor {
      xcursor-theme "catppuccin-latte-light-cursors"
      xcursor-size 24
    }

    prefer-no-csd

    environment {
      NIXOS_OZONE_WL "1"
      QT_QPA_PLATFORM "wayland"
      XCURSOR_THEME "catppuccin-latte-light-cursors"
      XCURSOR_SIZE "24"
    }

    // Window Rules
    window-rule {
      match app-id="^org\\.gnome\\.Nautilus$"
      open-floating true
    }
    window-rule {
      match app-id="^pavucontrol$"
      open-floating true
    }
    window-rule {
      match app-id="^nm-connection-editor$"
      open-floating true
    }
    window-rule {
      match app-id=r#"firefox$"# title="^Picture-in-Picture$"
      open-floating true
    }
    window-rule {
      geometry-corner-radius 8;
      clip-to-geometry true;
    }
    window-rule {
      match app-id="^code$"
      open-maximized true
    }
    window-rule {
      match app-id="^zen$"
      open-maximized true
    }
    window-rule {
      match app-id="^kitty$" title="^nc-pick$"
      open-floating true
    }


    binds {
      // Apps
      Mod+T { spawn "kitty"; }
      Mod+E { spawn "nautilus"; }
      Mod+Shift+E { spawn "kitty" "--override" "initial_window_width=1100" "--override" "initial_window_height=700" "--title" "nc-pick" "-e" "nc-pick"; }
      Alt+Space { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
      Super+Alt+L { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
      Mod+Q { close-window; }

      // Overview (niri native)
      Mod+O { toggle-overview; }

      // Fokus (Pfeiltasten + Vim-Keys)
      Mod+Left  { focus-column-left; }
      Mod+Down  { focus-window-down; }
      Mod+Up    { focus-window-up; }
      Mod+Right { focus-column-right; }
      Mod+H { focus-column-left; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      Mod+L { focus-column-right; }

      // Spalten/Fenster verschieben
      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Down  { move-window-down; }
      Mod+Ctrl+Up    { move-window-up; }
      Mod+Ctrl+Right { move-column-right; }
      Mod+Ctrl+H { move-column-left; }
      Mod+Ctrl+J { move-window-down; }
      Mod+Ctrl+K { move-window-up; }
      Mod+Ctrl+L { move-column-right; }

      // Erste/letzte Spalte
      Mod+Home { focus-column-first; }
      Mod+End  { focus-column-last; }

      // Workspaces (vertikal)
      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up   { focus-workspace-up; }
      Mod+U { focus-workspace-down; }
      Mod+I { focus-workspace-up; }
      Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
      Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }

      // Workspaces 1-9 direkt
      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+7 { focus-workspace 7; }
      Mod+8 { focus-workspace 8; }
      Mod+9 { focus-workspace 9; }

      // Fenster zu Workspace verschieben
      Mod+Ctrl+1 { move-column-to-workspace 1; }
      Mod+Ctrl+2 { move-column-to-workspace 2; }
      Mod+Ctrl+3 { move-column-to-workspace 3; }
      Mod+Ctrl+4 { move-column-to-workspace 4; }
      Mod+Ctrl+5 { move-column-to-workspace 5; }
      Mod+Ctrl+6 { move-column-to-workspace 6; }
      Mod+Ctrl+7 { move-column-to-workspace 7; }
      Mod+Ctrl+8 { move-column-to-workspace 8; }
      Mod+Ctrl+9 { move-column-to-workspace 9; }

      // Fensterverwaltung
      Mod+R       { switch-preset-column-width; }
      Mod+F       { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+C       { center-column; }
      Mod+V       { toggle-window-floating; }
      Mod+Comma   { consume-window-into-column; }
      Mod+Period  { expel-window-from-column; }
      Mod+Minus   { set-column-width "-10%"; }
      Mod+Equal   { set-column-width "+10%"; }

      // Fenster in/aus Spalte (tabs)
      Mod+BracketLeft  { consume-or-expel-window-left; }
      Mod+BracketRight { consume-or-expel-window-right; }

      // Screenshots (niri built-in, kein grim/slurp noetig)
      Print       { screenshot; }
      Ctrl+Print  { screenshot-screen; }
      Alt+Print   { screenshot-window; }

      // Audio
      XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+" "-l" "1.0"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"; }
      XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioMicMute     allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

      // Mediaplayer
      XF86AudioPlay { spawn "playerctl" "play-pause"; }
      XF86AudioStop { spawn "playerctl" "stop"; }
      XF86AudioPrev { spawn "playerctl" "previous"; }
      XF86AudioNext { spawn "playerctl" "next"; }

      // Helligkeit
      XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

      // Session
      Mod+Shift+D     { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }
      Mod+Shift+P     { power-off-monitors; }
    }
  '';

  home.pointerCursor = {
    gtk.enable = true;
    package    = pkgs.catppuccin-cursors.latteLight;
    name       = "catppuccin-latte-light-cursors";
    size       = 24;
  };

  # Sperrbildschirm (Catppuccin Mocha)
  programs.swaylock = {
    enable = true;
    settings = {
      color         = "1e1e2e";
      inside-color  = "1e1e2e";
      ring-color    = "89b4fa";
      key-hl-color  = "89b4fa";
      bs-hl-color   = "f38ba8";
      text-color    = "cdd6f4";
      font          = "JetBrainsMono Nerd Font";
    };
  };

  # Idle-Daemon
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "swaylock";
    };
    timeouts = [
      { timeout = 300; command = "swaylock"; }
    ];
  };

  # Noctalia Shell (ersetzt Waybar + Mako)
  programs.noctalia-shell.enable = true;

  # Status-Leiste (deaktiviert, durch Noctalia ersetzt)
  programs.waybar = {
    enable = false;
    settings = [{
      layer    = "top";
      position = "top";
      height   = 36;
      "margin-top"   = 5;
      "margin-left"  = 8;
      "margin-right" = 8;

      modules-left   = [ "niri/workspaces" "niri/window" ];
      modules-center = [ "clock" ];
      modules-right  = [ "cpu" "memory" "custom/mic" "pulseaudio" "network" "battery" "tray" "custom/power" ];

      "niri/workspaces" = {
        format = "{index}";
        on-click = "activate";
      };

      "niri/window" = {
        format = "{title}";
        max-length = 50;
      };

      cpu = {
        format   = "󰻠 {usage}%";
        interval = 3;
        tooltip  = false;
      };

      memory = {
        format         = "󰍛 {percentage}%";
        interval       = 3;
        tooltip-format = "{used:0.1f}G / {total:0.0f}G";
      };

      "custom/mic" = {
        exec        = "waybar-mic-status";
        return-type = "json";
        interval    = "once";
        signal      = 1;
        on-click    = "mic-toggle";
      };

      "custom/power" = {
        format   = "󰐥";
        on-click = "power-menu";
        tooltip  = false;
      };

      clock = {
        format         = " {:%H:%M  %a %d.%m}";
        tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
      };

      battery = {
        states          = { warning = 30; critical = 15; };
        format          = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons    = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        tooltip-format  = "{timeTo}";
      };

      network = {
        format-wifi         = "󰤨 {essid}";
        format-ethernet     = "󰈀 Ethernet";
        format-disconnected = "󰤮 offline";
        tooltip-format      = "{ifname}: {ipaddr}  {signalStrength}%";
        on-click            = "nm-connection-editor";
      };

      pulseaudio = {
        format       = "{icon} {volume}%";
        format-muted = "󰖁 Stumm";
        format-icons = { default = [ "󰕿" "󰖀" "󰕾" ]; };
        on-click     = "pavucontrol";
      };

      tray = {
        icon-size = 16;
        spacing   = 6;
      };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.88);
        color: #cdd6f4;
        border-radius: 12px;
      }

      /* ── Workspaces ─────────────────────────── */
      #workspaces {
        margin: 3px 0 3px 4px;
        padding: 0 3px;
        background: rgba(49, 50, 68, 0.7);
        border-radius: 10px;
      }

      #workspaces button {
        padding: 1px 9px;
        color: #6c7086;
        border-radius: 8px;
        margin: 2px 2px;
        background: transparent;
        transition: all 0.15s ease-in-out;
      }

      #workspaces button.active,
      #workspaces button.focused {
        color: #1e1e2e;
        background: #89b4fa;
      }

      #workspaces button:hover {
        color: #cdd6f4;
        background: rgba(137, 180, 250, 0.2);
      }

      /* ── Window title ───────────────────────── */
      #window {
        color: #7f849c;
        font-style: italic;
        padding: 0 12px;
      }

      /* ── Clock ──────────────────────────────── */
      #clock {
        background: rgba(137, 180, 250, 0.12);
        border: 1px solid rgba(137, 180, 250, 0.25);
        color: #cdd6f4;
        font-weight: bold;
        padding: 1px 16px;
        border-radius: 10px;
        margin: 3px 0;
      }

      /* ── Rechte Module (Pills) ──────────────── */
      #cpu,
      #memory,
      #custom-mic,
      #pulseaudio,
      #network,
      #battery,
      #tray,
      #custom-power {
        background: rgba(49, 50, 68, 0.7);
        border-radius: 10px;
        padding: 1px 10px;
        margin: 3px 2px;
      }

      #cpu    { color: #cba6f7; }
      #memory { color: #cba6f7; }

      #custom-mic         { color: #a6e3a1; }
      #custom-mic.muted   { color: #f38ba8; background: rgba(243, 139, 168, 0.12); }

      #pulseaudio         { color: #89b4fa; }
      #pulseaudio.muted   { color: #f38ba8; background: rgba(243, 139, 168, 0.12); }

      #network            { color: #89dceb; }
      #network.disconnected { color: #6c7086; }

      #battery            { color: #a6e3a1; }
      #battery.warning    { color: #f9e2af; }
      #battery.critical   { color: #f38ba8; background: rgba(243, 139, 168, 0.12); }

      #tray { padding: 2px 8px; }

      #custom-power {
        color: #f38ba8;
        background: rgba(243, 139, 168, 0.1);
        padding: 1px 12px;
        margin-right: 4px;
      }

      #custom-power:hover {
        background: rgba(243, 139, 168, 0.25);
      }
    '';
  };

  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";
    settings.confirm_os_window_close = 0;
  };

  # Lowercase icon-alias damit Noctalia org.gnome.nautilus (lowercased app-id) findet
  home.file.".local/share/icons/hicolor/scalable/apps/org.gnome.nautilus.svg".source =
    "${pkgs.nautilus}/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg";

  # Pakete
  home.packages = with pkgs; [
    fuzzel                     # App-Launcher (niri default)
    nautilus                   # File manager
    cliphist                   # Clipboard-Historie
    swaybg                     # Wallpaper-Daemon
    pavucontrol                # Lautstaerke-Mixer GUI
    networkmanagerapplet       # Netzwerk-Tray-Icon
    polkit_gnome               # Polkit-Authentifizierungsagent
    nerd-fonts.jetbrains-mono  # Icons fuer Waybar und Mako
    playerctl                  # MPRIS Media Controls
  ];
}
