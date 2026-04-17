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
      mouse {}
    }

    layout {
      gaps 16
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
    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "swaybg" "-i" "${wallpaper}" "-m" "fill"
    spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
    spawn-at-startup "nm-applet" "--indicator"

    // Hotkey-Overlay beim Start nicht anzeigen
    hotkey-overlay {
      skip-at-startup
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    prefer-no-csd

    environment {
      NIXOS_OZONE_WL "1"
    }

    // Window Rules
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

    binds {
      // Apps
      Mod+T { spawn "kitty"; }
      Alt+Space { spawn "fuzzel"; }
      Super+Alt+L { spawn "swaylock"; }
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
      Mod+Shift+E     { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }
      Mod+Shift+P     { power-off-monitors; }
    }
  '';

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

  # Benachrichtigungen (Catppuccin Mocha)
  services.mako = {
    enable = true;
    settings = {
      default-timeout  = 5000;
      background-color = "#1e1e2ecc";
      text-color       = "#cdd6f4";
      border-color     = "#89b4fa";
      border-radius    = 8;
      width            = 360;
      margin           = "12";
      padding          = "12";
      font             = "JetBrainsMono Nerd Font 11";
    };
  };

  # Status-Leiste mit nativen niri-Modulen
  programs.waybar = {
    enable = true;
    settings = [{
      layer    = "top";
      position = "top";
      height   = 34;

      modules-left   = [ "niri/workspaces" "niri/window" ];
      modules-right  = [ "clock" "pulseaudio" "network" "battery" "tray" ];

      "niri/workspaces" = {
        format = "{index}";
        on-click = "activate";
      };

      "niri/window" = {
        format = "{title}";
        max-length = 50;
      };

      clock = {
        format         = " {:%H:%M  %a %d.%m.%Y}";
        tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
      };

      battery = {
        states          = { warning = 30; critical = 15; };
        format          = "{icon} {capacity}%";
        format-charging = " {capacity}%";
        format-icons    = [ " " " " " " " " " " ];
        tooltip-format  = "{timeTo}";
      };

      network = {
        format-wifi         = " {essid}";
        format-ethernet     = " Ethernet";
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
        icon-size = 18;
        spacing   = 8;
      };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.92);
        color: #cdd6f4;
        border-bottom: 2px solid rgba(137, 180, 250, 0.4);
      }

      #workspaces button {
        padding: 2px 8px;
        color: #6c7086;
        border-radius: 4px;
        margin: 2px 2px;
      }

      #workspaces button.focused {
        color: #89b4fa;
        background: rgba(137, 180, 250, 0.15);
      }

      #workspaces button.active {
        color: #89b4fa;
        background: rgba(137, 180, 250, 0.15);
      }

      #window {
        padding: 2px 14px;
        color: #a6adc8;
        font-style: italic;
      }

      #clock {
        padding: 2px 14px;
        color: #cdd6f4;
      }

      #battery,
      #network,
      #pulseaudio,
      #tray {
        padding: 2px 10px;
        color: #cdd6f4;
      }

      #battery.warning { color: #f9e2af; }
      #battery.critical { color: #f38ba8; }
      #battery.critical:not(.charging) {
        background: rgba(243, 139, 168, 0.15);
        border-radius: 4px;
      }
    '';
  };

  # Pakete
  home.packages = with pkgs; [
    kitty                      # Terminal
    fuzzel                     # App-Launcher (niri default)
    cliphist                   # Clipboard-Historie
    swaybg                     # Wallpaper-Daemon
    pavucontrol                # Lautstaerke-Mixer GUI
    networkmanagerapplet       # Netzwerk-Tray-Icon
    polkit_gnome               # Polkit-Authentifizierungsagent
    nerd-fonts.jetbrains-mono  # Icons fuer Waybar und Mako
    playerctl                  # MPRIS Media Controls
  ];
}
