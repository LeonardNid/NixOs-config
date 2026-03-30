{ pkgs, ... }:

{
  home.username = "leonardn";
  home.homeDirectory = "/home/leonardn";
  home.stateVersion = "25.11";

  # User-spezifische Packages (Tools die nur du brauchst)
  programs.neovim = {
    enable = true;
    extraConfig = ''
      set clipboard=unnamedplus
    '';
  };

  home.packages = with pkgs; [
    wl-clipboard
    looking-glass-client
    keymapp
    scream
    libnotify
    (writeShellScriptBin "rebuild" ''
      cd /etc/nixos
      git add .
      if ! git diff --cached --quiet; then
        git commit -m "''${1:-nixos: $(date '+%Y-%m-%d %H:%M')}"
      fi
      sudo nixos-rebuild switch --flake /etc/nixos#leonardn
      git push
    '')
    (writeShellScriptBin "vm" ''
      VM_NAME="windows11"

      case "''${1:-}" in
        start)
          echo "=== VM starten ==="

          # Festplatten unmounten (ignoriere Fehler falls nicht gemountet)
          echo "Festplatten unmounten..."
          for dev in /dev/sdb1 /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3 /dev/nvme0n1p4; do
            if mountpoint -q "$(findmnt -n -o TARGET "$dev" 2>/dev/null)" 2>/dev/null; then
              sudo umount "$dev" && echo "  $dev unmounted"
            fi
          done

          # VM starten
          echo "VM starten..."
          sudo virsh start "$VM_NAME"

          # Warten bis KVMFR bereit ist
          sleep 2

          # Idle/Sleep blockieren solange VM läuft
          systemd-inhibit --what=idle:sleep --who="Windows VM" --why="Gaming auf VM" sleep infinity &
          echo $! > /tmp/vm-inhibit.pid

          # Looking Glass starten (Vollbild, kein Auto-Input-Grab, Log in Datei)
          echo "Looking Glass starten..."
          looking-glass-client -F -f /dev/kvmfr0 \
            win:size=2560x1440 win:dontUpscale=on \
            input:captureOnFocus=no input:grabKeyboardOnFocus=no \
            win:requestActivation=no \
            spice:enable=no \
            > /tmp/looking-glass.log 2>&1 &
          LG_PID=$!

          # Background-Watcher: räumt automatisch auf wenn VM stoppt
          (while sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; do
            sleep 5
          done
          pkill -f looking-glass-client 2>/dev/null
          kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
          rm -f /tmp/vm-inhibit.pid
          notify-send "Windows VM" "VM gestoppt, aufgeräumt.") &

          echo "Looking Glass läuft (PID: $LG_PID)"
          echo "Log: /tmp/looking-glass.log"
          echo ""
          echo "=== VM läuft! ScrollLock = Input umschalten ==="
          echo "VM stoppt automatisch wenn Windows herunterfährt."
          echo "Oder manuell: vm stop"
          ;;

        stop)
          echo "=== VM beenden ==="

          # Looking Glass beenden
          pkill -f looking-glass-client 2>/dev/null && echo "Looking Glass beendet"

          # Idle-Inhibitor freigeben
          kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
          rm -f /tmp/vm-inhibit.pid

          # Falls VM noch läuft, herunterfahren
          if sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
            echo "VM herunterfahren..."
            sudo virsh shutdown "$VM_NAME"

            # Warten bis VM aus ist (max 60 Sekunden)
            for i in $(seq 1 60); do
              if ! sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
                echo "VM ist aus."
                break
              fi
              sleep 1
            done

            # Falls VM noch läuft, force stop
            if sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
              echo "VM reagiert nicht, erzwinge Shutdown..."
              sudo virsh destroy "$VM_NAME"
            fi
          else
            echo "VM ist bereits aus."
          fi

          echo "Festplatten sind wieder verfügbar (KDE mountet automatisch)"
          echo "=== Fertig ==="
          ;;

        status)
          sudo virsh domstate "$VM_NAME"
          ;;

        *)
          echo "Verwendung: vm {start|stop|status}"
          ;;
      esac
    '')
  ];

  # Git Konfiguration
  programs.git = {
    enable = true;
    userName = "Leonard Niedens";
    userEmail = "niedens03@gmail.com";
    extraConfig.init.defaultBranch = "main";
  };

  # Zsh Konfiguration
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
    };
  };

  # Scream Audio Receiver (empfängt Sound von der Windows VM)
  systemd.user.services.scream = {
    Unit = {
      Description = "Scream Audio Receiver";
    };
    Service = {
      ExecStart = "${pkgs.scream}/bin/scream -i virbr0";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Starship Prompt
  programs.starship = {
    enable = true;
  };

  # Home Manager selbst verwalten lassen
  programs.home-manager.enable = true;
}
