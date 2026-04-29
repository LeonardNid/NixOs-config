{ pkgs, ... }:

let
  wallpaper = "/home/leonardn/nixos-config/wallpapers/surreal-underwater-3840x2160-26042.jpg";
in
{
  # Niri Window Manager
  programs.niri.config = ''
    input {
      keyboard {
        xkb { layout "de"; }
        repeat-delay 350
        repeat-rate 25
        numlock
      }
      mouse {
        accel-speed 0.0        // -1.0 (langsam) bis 1.0 (schnell), 0.0 = Standard
        // accel-profile "flat" // "flat" = keine Beschleunigung, "adaptive" = Standard
        scroll-factor 1.5      // Scroll-Geschwindigkeit: 0.5 = halb so schnell, 2.0 = doppelt
      }
      touchpad {
        // AmazonBasics Touchpad: Firmware schickt das Click-Bit nur im Boot-
        // Mode, im PTP-Mode (den hid-multitouch nutzt) nie — daher kein phys.
        // Klick. Tap-to-Click ist der Ersatz (1 Finger = L, 2 = R, 3 = M).
        // Siehe documentation/amazonbasics-touchpad.md.
        tap
        natural-scroll
        drag-lock
        scroll-factor 0.8
        accel-speed 0.2
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

    // Monitore
    output "DP-1" {
      mode "2560x1440@170.001"
      position x=0 y=0
    }
    output "HDMI-A-1" {
      position x=2560 y=0
    }

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
      Mod+Return { spawn "kitty"; }
      Mod+E { spawn "nautilus"; }
      Mod+Shift+E { spawn "kitty" "--override" "initial_window_width=1100" "--override" "initial_window_height=700" "--title" "nc-pick" "-e" "nc-pick"; }
      Alt+Space { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
      Super+Alt+L { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
      Mod+I { close-window; }

      // Overview (niri native)
      Mod+O { toggle-overview; }

      // Fokus (Pfeiltasten + Neo-Keys)
      // Tastaturlayout: Neo (Deutsch) – statt HJKL wird SNRT verwendet
      //   S = links, N = unten, R = oben, T = rechts
      Mod+Left  { focus-column-left; }
      Mod+Down  { focus-window-down; }
      Mod+Up    { focus-window-up; }
      Mod+Right { focus-column-right; }
      Mod+S { focus-column-left; }
      Mod+N { focus-window-down; }
      Mod+R { focus-window-up; }
      Mod+T { focus-column-right; }

      // Scrollen durch Columns/Workspaces mit Mausrad
      Mod+WheelScrollRight cooldown-ms=150 { focus-workspace-down; }
      Mod+WheelScrollLeft  cooldown-ms=150 { focus-workspace-up; }
      Mod+WheelScrollDown  cooldown-ms=150 { focus-column-right; }
      Mod+WheelScrollUp    cooldown-ms=150 { focus-column-left; }

      // Monitor-Fokus
      Mod+Shift+Left  { focus-monitor-left; }
      Mod+Shift+Right { focus-monitor-right; }
      Mod+Shift+S { focus-monitor-left; }
      Mod+Shift+T { focus-monitor-right; }

      // Fenster auf anderen Monitor verschieben
      Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
      Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
      Mod+Shift+Ctrl+S { move-column-to-monitor-left; }
      Mod+Shift+Ctrl+T { move-column-to-monitor-right; }

      // Spalten/Fenster verschieben
      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Down  { move-window-down; }
      Mod+Ctrl+Up    { move-window-up; }
      Mod+Ctrl+Right { move-column-right; }
      Mod+Ctrl+S { move-column-left; }
      Mod+Ctrl+N { move-window-down; }
      Mod+Ctrl+R { move-window-up; }
      Mod+Ctrl+T { move-column-right; }

      // Erste/letzte Spalte
      Mod+Home { focus-column-first; }
      Mod+End  { focus-column-last; }

      // Workspaces (vertikal)
      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up   { focus-workspace-up; }

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
      Mod+W       { switch-preset-column-width; }
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
      XF86AudioMicMute     allow-when-locked=true { spawn "mic-toggle"; }
      F24                  allow-when-locked=true { spawn "sh" "-c" "vesktop-toggle; mic-toggle"; }

      // Mediaplayer
      XF86AudioPlay { spawn "playerctl" "play-pause"; }
      XF86AudioStop { spawn "playerctl" "stop"; }
      XF86AudioPrev { spawn "playerctl" "previous"; }
      XF86AudioNext { spawn "playerctl" "next"; }

      // Session
      Mod+Shift+D     { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }
      Mod+Shift+P     { power-off-monitors; }
    }
  '';

  # Sperrbildschirm (Catppuccin Mocha)
  home.pointerCursor = {
    gtk.enable = true;
    package    = pkgs.catppuccin-cursors.latteLight;
    name       = "catppuccin-latte-light-cursors";
    size       = 24;
  };

  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";
    settings.confirm_os_window_close = 0;
  };

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

  # Benachrichtigungen (Catppuccin Mocha) — deaktiviert, Noctalia übernimmt
  services.mako = {
    enable = false;
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

  programs.noctalia-shell.enable = true;

  # Status-Leiste mit nativen niri-Modulen — deaktiviert, Noctalia übernimmt
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
      modules-right  = [ "cpu" "memory" "custom/mic" "pulseaudio" "network" "custom/vm" "tray" "custom/power" ];

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

      "custom/vm" = {
        exec        = "waybar-vm-status";
        return-type = "json";
        interval    = 1;
        on-click    = "vm-menu";
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

      network = {
        format-wifi         = "󰤨 {essid}";
        format-ethernet     = "󰈀 Ethernet";
        format-disconnected = "󰤮 offline";
        tooltip-format      = "{ifname}: {ipaddr}";
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
      #custom-vm,
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

      #tray { padding: 2px 8px; }

      #custom-vm              { color: #6c7086; }
      #custom-vm.running      { color: #a6e3a1; }
      #custom-vm.paused       { color: #f9e2af; background: rgba(249, 226, 175, 0.08); }
      #custom-vm.progress     { color: #89b4fa; animation: vm-pulse 1s ease-in-out infinite alternate; }
      #custom-vm.running:hover  { background: rgba(166, 227, 161, 0.12); }

      @keyframes vm-pulse {
        from { opacity: 1.0; }
        to   { opacity: 0.5; }
      }

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

  # Lowercase icon-alias damit Noctalia org.gnome.nautilus (lowercased app-id) findet
  home.file.".local/share/icons/hicolor/scalable/apps/org.gnome.nautilus.svg".source =
    "${pkgs.nautilus}/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg";

  # Pakete
  home.packages = with pkgs; [
    heroic                     # Epic/GOG Games Launcher (Rocket League via Proton)
    protonup-qt                # Proton-GE-Builds verwalten
    mangohud                   # FPS/GPU-Overlay (Shift+F12)
    fuzzel                     # App-Launcher
    nautilus                   # File manager
    cliphist                   # Clipboard-Historie
    swaybg                     # Wallpaper-Daemon
    pavucontrol                # Lautstaerke-Mixer GUI
    networkmanagerapplet       # Netzwerk-Tray-Icon
    polkit_gnome               # Polkit-Authentifizierungsagent
    nerd-fonts.jetbrains-mono  # Icons fuer Waybar und Mako
    playerctl                  # MPRIS Media Controls

    (pkgs.writeShellScriptBin "waybar-vm-status" ''
      VM="windows11"
      PROGRESS="/tmp/vm-waybar-progress"
      CACHE="/tmp/vm-waybar-cache"
      STAMP="/tmp/vm-waybar-stamp"

      # During active operation: return immediately (called every 1s)
      if [ -f "$PROGRESS" ]; then
        cat "$PROGRESS"
        exit 0
      fi

      # Idle: only query virsh every 30 seconds, cache the result
      NOW=$(date +%s)
      if [ -f "$STAMP" ] && [ -f "$CACHE" ]; then
        LAST=$(cat "$STAMP")
        if [ $(( NOW - LAST )) -lt 30 ]; then
          cat "$CACHE"
          exit 0
        fi
      fi

      echo "$NOW" > "$STAMP"
      STATE=$(sudo virsh domstate "$VM" 2>/dev/null | xargs 2>/dev/null)
      case "$STATE" in
        "running")
          RESULT='{"text":"󰍹 läuft","class":"running","tooltip":"Windows VM läuft – klicken für Menü"}'
          ;;
        "paused")
          RESULT='{"text":"󰍹 pause","class":"paused","tooltip":"Windows VM pausiert – klicken für Menü"}'
          ;;
        "shut off")
          RESULT='{"text":"󰍹","class":"stopped","tooltip":"Windows VM aus – klicken zum Starten"}'
          ;;
        *)
          RESULT='{"text":"󰍹","class":"stopped","tooltip":"Windows VM: Status unbekannt"}'
          ;;
      esac
      echo "$RESULT" > "$CACHE"
      echo "$RESULT"
    '')

    (pkgs.writeShellScriptBin "vm-start-waybar" ''
      VM="windows11"
      BOOT_DELAY=30
      STATE_FILE="/tmp/vm-waybar-progress"
      LOG="/tmp/vm-start-waybar.log"

      echo "=== $(date '+%H:%M:%S') START (PID $$) ===" >> "$LOG"
      exec 2>>"$LOG"

      _status() { printf '%s' "$1" > "$STATE_FILE"; }
      _done()   { rm -f "$STATE_FILE"; }

      _status '{"text":"󰍹 …","class":"progress","tooltip":"Festplatten unmounten..."}'
      echo "$(date '+%H:%M:%S') unmount loop" >> "$LOG"
      for dev in /dev/sdb1 /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3 /dev/nvme0n1p4; do
        if mountpoint -q "$(findmnt -n -o TARGET "$dev" 2>/dev/null)" 2>/dev/null; then
          echo "$(date '+%H:%M:%S') unmounting $dev" >> "$LOG"
          timeout 5 sudo umount "$dev" 2>/dev/null || echo "$(date '+%H:%M:%S') umount $dev failed/busy" >> "$LOG"
        fi
      done
      echo "$(date '+%H:%M:%S') unmount done" >> "$LOG"

      _status '{"text":"󰍹 …","class":"progress","tooltip":"VM startet..."}'
      echo "$(date '+%H:%M:%S') virsh start" >> "$LOG"
      if ! sudo virsh start "$VM"; then
        echo "$(date '+%H:%M:%S') virsh start FAILED" >> "$LOG"
        notify-send -u critical "Windows VM" "Fehler beim Starten! Log: $LOG"
        _done; exit 1
      fi
      echo "$(date '+%H:%M:%S') virsh start OK" >> "$LOG"

      sleep 0.5
      echo "init_linux_after_qemu_start" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
      sleep 2

      systemd-inhibit --what=idle:sleep --who="Windows VM" --why="Gaming auf VM" sleep infinity &
      echo $! > /tmp/vm-inhibit.pid

      for i in $(seq $BOOT_DELAY -1 1); do
        _status "{\"text\":\"󰍹 ''${i}s\",\"class\":\"progress\",\"tooltip\":\"Windows bootet... noch ''${i}s\"}"
        sleep 1
      done

      _status '{"text":"󰍹 …","class":"progress","tooltip":"Looking Glass startet..."}'
      niri msg action focus-monitor-left 2>/dev/null || true
      sleep 0.3
      looking-glass-client -F -f /dev/kvmfr0 \
        win:size=2560x1440 win:dontUpscale=on \
        input:captureOnFocus=no input:grabKeyboardOnFocus=no \
        input:escapeKey=KEY_PAUSE \
        win:requestActivation=no \
        spice:enable=no \
        > /tmp/looking-glass.log 2>&1 &

      _done

      # Background watcher: cleanup when VM stops
      (while sudo virsh domstate "$VM" 2>/dev/null | grep -q "running"; do
        sleep 5
      done
      echo "force_linux" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
      pkill -f looking-glass-client 2>/dev/null
      kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
      rm -f /tmp/vm-inhibit.pid
      notify-send "Windows VM" "VM gestoppt, aufgeräumt.") &
    '')

    (pkgs.writeShellScriptBin "vm-stop-waybar" ''
      VM="windows11"
      STATE_FILE="/tmp/vm-waybar-progress"

      _status() { printf '%s' "$1" > "$STATE_FILE"; }
      _done()   { rm -f "$STATE_FILE"; }

      pkill -f looking-glass-client 2>/dev/null
      kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
      rm -f /tmp/vm-inhibit.pid

      if sudo virsh domstate "$VM" 2>/dev/null | grep -q "running"; then
        _status '{"text":"󰍹 …","class":"progress","tooltip":"VM fährt herunter..."}'
        sudo virsh shutdown "$VM"

        for i in $(seq 60 -1 1); do
          if ! sudo virsh domstate "$VM" 2>/dev/null | grep -q "running"; then
            break
          fi
          _status "{\"text\":\"󰍹 …\",\"class\":\"progress\",\"tooltip\":\"Shutdown... max ''${i}s\"}"
          sleep 1
        done

        if sudo virsh domstate "$VM" 2>/dev/null | grep -q "running"; then
          _status '{"text":"󰍹 …","class":"progress","tooltip":"Erzwinge Shutdown..."}'
          sudo virsh destroy "$VM"
          sleep 1
        fi
      fi

      echo "force_linux" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
      _done
    '')

    (pkgs.writeShellScriptBin "vm-menu" ''
      VM="windows11"
      # Block clicks while an operation is already running
      [ -f /tmp/vm-waybar-progress ] && exit 0
      STATE=$(sudo virsh domstate "$VM" 2>/dev/null | xargs 2>/dev/null)
      case "$STATE" in
        "running")
          LINES=3
          OPTS=$(printf "󰓛  Stoppen\n󰏤  Pausieren\n󰆁  Fixcon")
          ;;
        "paused")
          LINES=2
          OPTS=$(printf "▶  Fortsetzen\n󰓛  Stoppen")
          ;;
        *)
          LINES=1
          OPTS="▶  Starten"
          ;;
      esac
      CHOICE=$(echo "$OPTS" | fuzzel --dmenu --width=22 --lines=$LINES --prompt="󰍹  ")
      [ -z "$CHOICE" ] && exit 0
      case "$CHOICE" in
        *Stoppen*)    (setsid vm-stop-waybar &) ;;
        *Pausieren*)  vm pause ;;
        *Fortsetzen*) vm resume ;;
        *Starten*)    (setsid vm-start-waybar &) ;;
        *Fixcon*)     vm fixcon ;;
      esac
    '')

    (pkgs.writeShellScriptBin "waybar-restart" ''
      pkill -x waybar 2>/dev/null
      sleep 0.5
      exec waybar
    '')
  ];
}
