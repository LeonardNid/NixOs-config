{ pkgs, ... }:

let
  polkitAgent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";

  wallpapername = "surreal-underwater-3840x2160-26042.jpg";
in
{
  # Hyprland Window Manager
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Variablen
      "$mod"      = "SUPER";
      "$terminal" = "kitty";
      "$menu"     = "wofi --show drun";

      monitor = ",preferred,auto,1";

      # Autostart
      exec-once = [
        # NEU: DBus updaten, KWallet initialisieren und Daemon starten
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
        "kwalletd6"

        polkitAgent
        "waybar"
        "mako"
        "hyprpaper -c ~/.config/hypr/hyprpaper.conf"
        "wl-paste --watch cliphist store"
        "nm-applet --indicator"
      ];

      # Input
      input = {
        kb_layout    = "de";
        follow_mouse = 1;
        sensitivity  = 0;
        touchpad = {
          natural_scroll      = true;
          "tap-to-click"      = true;
          disable_while_typing = true;
        };
      };

      # Touchpad-Gesten (Workspace-Wechsel via 3-Finger-Swipe)
      # Seit 0.51: gesture-Bindings im gestures-Block, Richtung = horizontal
      gestures = {
        workspace_swipe_invert   = true;
        workspace_swipe_distance = 400;
        gesture = [ "3, horizontal, workspace" ];
      };

      # Allgemeines Aussehen
      general = {
        gaps_in    = 5;
        gaps_out   = 10;
        border_size = 2;
        "col.active_border"   = "rgba(89b4faff)";
        "col.inactive_border" = "rgba(585b70aa)";
        layout = "scrolling";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled  = true;
          size     = 4;
          passes   = 2;
          vibrancy = 0.1696;
        };
        shadow = { enabled = false; };
      };

      animations = {
        enabled = true;
        bezier = "easeOut, 0.05, 0.9, 0.1, 1.0";
        animation = [
          "windows,    1, 4, easeOut, slide"
          "windowsOut, 1, 4, easeOut, slide"
          "border,     1, 8, default"
          "fade,       1, 5, default"
          "workspaces, 1, 4, easeOut, slide"
        ];
      };

      scrolling = {
        column_width             = 0.5;
        fullscreen_on_one_column = true;
        follow_focus             = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo   = true;
      };

      # Keybindings
      bind = [
        # Fenster
        "$mod, Return,  exec,          $terminal"
        "ALT, Space,    exec,          $menu"
        "$mod, Q,       killactive"
        "$mod, D,       workspace,     e-1"
        "$mod, F,       workspace,     e+1"
        "$mod SHIFT, F, fullscreen,    0"
        "$mod SHIFT, T, togglefloating"
        "$mod, L,       exec,          hyprlock"

        # Clipboard-Historie (cliphist + wofi)
        "$mod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        # Screenshot: Bereich → Clipboard
        ", Print,     exec, grim -g \"$(slurp)\" - | wl-copy"
        # Screenshot: Vollbild → Clipboard
        "$mod, Print, exec, grim - | wl-copy"

        # Fokus mit Pfeiltasten (Scrolling Layout)
        "$mod, left,  layoutmsg, focus l"
        "$mod, right, layoutmsg, focus r"
        "$mod, up,    layoutmsg, focus u"
        "$mod, down,  layoutmsg, focus d"
        # Fokus mit HJKL (L frei lassen – ist Sperrbildschirm)
        "$mod, H, layoutmsg, focus l"
        "$mod, J, layoutmsg, focus d"
        "$mod, K, layoutmsg, focus u"

        # Spaltenbreite anpassen
        "$mod, minus, layoutmsg, colresize -conf"
        "$mod, equal, layoutmsg, colresize +conf"
        # Spalte tauschen
        "$mod SHIFT, left,  layoutmsg, swapcol l"
        "$mod SHIFT, right, layoutmsg, swapcol r"

        # Workspaces 1–6 wechseln
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"

        # Fenster in Workspace verschieben
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"

        # Lautstärke (PipeWire/wpctl)
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Helligkeit (brightnessctl, kommt aus system/laptop.nix)
        ", XF86MonBrightnessUp,   exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      # Maus: Fenster ziehen und resizen
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Sperrbildschirm
  programs.hyprlock = {
    enable = true;
    extraConfig = ''
      general {
        disable_loading_bar = true
        hide_cursor = true
      }

      background {
        monitor =
        path = screenshot
        blur_passes = 3
        blur_size = 8
      }

      input-field {
        monitor =
        size = 300, 50
        position = 0, -80
        halign = center
        valign = center
        dots_center = true
        fade_on_empty = false
        placeholder_text = <i>Passwort...</i>
        check_color = rgb(89b4fa)
        fail_color  = rgb(f38ba8)
        inner_color = rgb(1e1e2e)
        outer_color = rgb(89b4fa)
        font_color  = rgb(cdd6f4)
      }
    '';
  };

  # Idle-Daemon: automatisches Sperren + DPMS
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd         = "hyprlock";
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };
      listener = [
        {
          timeout    = 300;  # 5 min → sperren
          on-timeout = "hyprlock";
        }
        {
          timeout    = 600;  # 10 min → Bildschirm aus
          on-timeout = "hyprctl dispatch dpms off";
          on-resume  = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  # Benachrichtigungen
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      background-color = "#1e1e2ecc";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-radius = 8;
      width = 360;
      margin = "12";
      padding = "12";
      font = "JetBrainsMono Nerd Font 11";
    };
  };

  # Status-Leiste
  programs.waybar = {
    enable = true;
    settings = [{
      layer    = "top";
      position = "top";
      height   = 34;

      modules-left   = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

      "hyprland/workspaces" = {
        format   = "{id}";
        on-click = "activate";
      };

      "hyprland/window" = {
        max-length = 60;
      };

      clock = {
        format         = " {:%H:%M}   {:%a %d.%m.%Y}";
        tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
      };

      battery = {
        states           = { warning = 30; critical = 15; };
        format           = "{icon} {capacity}%";
        format-charging  = " {capacity}%";
        format-icons     = [ " " " " " " " " " " ];
        tooltip-format   = "{timeTo}";
      };

      network = {
        format-wifi       = " {essid}";
        format-ethernet   = " Ethernet";
        format-disconnected = "󰤮 offline";
        tooltip-format    = "{ifname}: {ipaddr}  {signalStrength}%";
        on-click          = "nm-connection-editor";
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
        padding: 2px 10px;
        color: #6c7086;
        background: transparent;
        border: none;
        border-radius: 4px;
        margin: 4px 2px;
      }

      #workspaces button.active {
        color: #89b4fa;
        background: rgba(137, 180, 250, 0.15);
      }

      #workspaces button:hover {
        background: rgba(137, 180, 250, 0.08);
        color: #cdd6f4;
      }

      #window {
        padding: 2px 10px;
        color: #a6adc8;
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

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/leonardn/nixos-config/wallpapers/${wallpapername}

    wallpaper {
      monitor = eDP-1
      path = /home/leonardn/nixos-config/wallpapers/${wallpapername}
      fit_mode = cover
    }

    splash = false
  '';
  
  # Pakete
  home.packages = with pkgs; [
    kitty                      # Terminal
    wofi                       # App-Launcher
    grim                       # Screenshot
    slurp                      # Bildschirmbereich-Auswahl
    cliphist                   # Clipboard-Historie
    hyprpaper                  # Wallpaper-Daemon
    pavucontrol                # Lautstärke-Mixer GUI
    networkmanagerapplet        # Netzwerk-Tray-Icon
    polkit_gnome               # Polkit-Authentifizierungsagent
    nerd-fonts.jetbrains-mono  # Icons für Waybar und Mako
  ];
}
