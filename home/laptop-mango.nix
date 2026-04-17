{ pkgs, ... }:

let
  polkitAgent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  wallpaper    = "/home/leonardn/nixos-config/wallpapers/surreal-underwater-3840x2160-26042.jpg";
in
{
  # Mango Window Manager
  wayland.windowManager.mango = {
    enable = true;

    settings = {
      # --- Aussehen (Catppuccin Mocha) ---
      borderpx      = 2;
      border_radius = 8;
      focuscolor    = "0x89b4faff";
      bordercolor   = "0x585b70aa";
      rootcolor     = "0x1e1e2eff";
      gappih = 5; gappiv = 5;
      gappoh = 10; gappov = 10;

      # --- Effekte ---
      blur                  = 1;
      blur_params_radius    = 4;
      blur_params_num_passes = 2;
      shadows               = 0;
      focused_opacity       = 1.0;
      unfocused_opacity     = 1.0;

      # --- Animationen ---
      animations           = 1;
      animation_type_open  = "slide";
      animation_type_close = "fade";
      animation_duration_open  = 150;
      animation_duration_close = 100;

      # --- Scroller ---
      scroller_default_proportion        = 0.5;
      scroller_proportion_preset         = "0.333,0.5,0.667,1.0";
      scroller_focus_center              = 0;
      scroller_default_proportion_single = 1.0;

      # --- Overview ---
      enable_hotarea = 0;
      overviewgappi  = 5;
      overviewgappo  = 30;

      # --- Input ---
      xkb_rules_layout        = "de";
      sloppyfocus             = 1;
      tap_to_click            = 1;
      disable_while_typing    = 1;
      trackpad_natural_scrolling = 1;
      repeat_rate  = 25;
      repeat_delay = 350;

      # --- Tags (1-4 Scroller, 5 Tile, 6 Monocle) ---
      tagrule = [
        "id:1,layout_name:scroller"
        "id:2,layout_name:scroller"
        "id:3,layout_name:scroller"
        "id:4,layout_name:scroller"
        "id:5,layout_name:tile"
        "id:6,layout_name:monocle"
      ];

      # --- Keybindings ---
      bind = [
        # Apps
        "SUPER,Return,spawn,kitty"
        "ALT,space,spawn,rofi -show drun"
        "SUPER,q,killclient,"
        "SUPER+SHIFT,r,reload_config"

        # Window-States
        "SUPER+SHIFT,f,togglefullscreen,"
        "SUPER+SHIFT,t,togglefloating,"
        "SUPER,l,spawn,swaylock"
        "ALT,Tab,toggleoverview,"

        # Focus (Pfeiltasten + HJK)
        "SUPER,Left,focusdir,left"
        "SUPER,Right,focusdir,right"
        "SUPER,Up,focusdir,up"
        "SUPER,Down,focusdir,down"
        "SUPER,h,focusdir,left"
        "SUPER,j,focusdir,down"
        "SUPER,k,focusdir,up"

        # Fenster tauschen
        "SUPER+SHIFT,Left,exchange_client,left"
        "SUPER+SHIFT,Right,exchange_client,right"

        # Tags navigieren (D/F = links/rechts)
        "SUPER,d,viewtoleft,0"
        "SUPER,f,viewtoright,0"

        # Tags 1-6 direkt
        "SUPER,1,view,1,0"
        "SUPER,2,view,2,0"
        "SUPER,3,view,3,0"
        "SUPER,4,view,4,0"
        "SUPER,5,view,5,0"
        "SUPER,6,view,6,0"

        # Fenster zu Tag verschieben
        "SUPER+SHIFT,1,tag,1,0"
        "SUPER+SHIFT,2,tag,2,0"
        "SUPER+SHIFT,3,tag,3,0"
        "SUPER+SHIFT,4,tag,4,0"
        "SUPER+SHIFT,5,tag,5,0"
        "SUPER+SHIFT,6,tag,6,0"

        # Scroller: Fensterbreite anpassen
        "SUPER,minus,switch_proportion_preset,"
        "SUPER,equal,set_proportion,1.0"

        # Clipboard
        "SUPER,v,spawn,cliphist list | rofi -dmenu | cliphist decode | wl-copy"

        # Screenshots
        ''NONE,Print,spawn,grim -g "$(slurp)" - | wl-copy''
        "SUPER,Print,spawn,grim - | wl-copy"

        # Audio
        "NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        "NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Helligkeit
        "NONE,XF86MonBrightnessUp,spawn,brightnessctl set 10%+"
        "NONE,XF86MonBrightnessDown,spawn,brightnessctl set 10%-"
      ];

      # --- Maus ---
      mousebind = [
        "SUPER,btn_left,moveresize,curmove"
        "SUPER,btn_right,moveresize,curresize"
      ];

      # --- Gesten (3-Finger = Fenster, 4-Finger = Tags) ---
      gesturebind = [
        "none,left,3,focusdir,left"
        "none,right,3,focusdir,right"
        "none,left,4,viewtoleft,0"
        "none,right,4,viewtoright,0"
      ];

      # --- Window Rules ---
      windowrule = [
        "isfloating:1,width:900,height:700,appid:pavucontrol"
        "isfloating:1,width:900,height:600,appid:nm-connection-editor"
      ];
    };

    # Autostart
    autostart_sh = ''
      swaybg -i ${wallpaper} -m fill &
      waybar &
      mako &
      wl-paste --watch cliphist store &
      nm-applet --indicator &
      ${polkitAgent} &
      ${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init
      kwalletd6 &
    '';
  };

  # Sperrbildschirm
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

  # Idle-Daemon: automatisches Sperren
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "swaylock";
    };
    timeouts = [
      { timeout = 300; command = "swaylock"; }
    ];
  };

  # Benachrichtigungen (identisch mit Hyprland)
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

  # Status-Leiste (ohne Hyprland-spezifische Module)
  programs.waybar = {
    enable = true;
    settings = [{
      layer    = "top";
      position = "top";
      height   = 34;

      modules-left   = [ "clock" ];
      modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

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
    rofi                       # App-Launcher + Window-Overview
    grim                       # Screenshot
    slurp                      # Bildschirmbereich-Auswahl
    cliphist                   # Clipboard-Historie
    swaybg                     # Wallpaper-Daemon
    pavucontrol                # Lautstärke-Mixer GUI
    networkmanagerapplet       # Netzwerk-Tray-Icon
    polkit_gnome               # Polkit-Authentifizierungsagent
    nerd-fonts.jetbrains-mono  # Icons für Waybar und Mako
  ];
}
