{ pkgs, ... }:

let
  controllerXml = pkgs.writeText "dualsense-hostdev.xml" ''
    <hostdev mode="subsystem" type="usb" managed="yes">
      <source>
        <vendor id="0x054c"/>
        <product id="0x0ce6"/>
      </source>
    </hostdev>
  '';

  # Läuft als root im Hintergrund (überlebt niri-Neustart)
  # Ablauf: SDDM stop → nvidia entladen → GPU detach → VM start → SDDM start → LG
  vmStartBg = pkgs.writeShellScript "vm-start-bg" ''
    VM_NAME="windows11"
    VIRSH="${pkgs.libvirt}/bin/virsh"
    BOOT_WAIT=20
    USER_NAME="leonardn"
    USER_ID=1000
    USER_RUNTIME="/run/user/$USER_ID"

    log() { logger -t vm-start "$*"; }

    abort() {
      log "Abbruch: $1 — stelle nvidia wieder her"
      "$VIRSH" nodedev-reattach pci_0000_01_00_0 2>/dev/null || true
      "$VIRSH" nodedev-reattach pci_0000_01_00_1 2>/dev/null || true
      modprobe nvidia_modeset nvidia_drm 2>/dev/null || true
      systemctl start display-manager
      exit 1
    }

    log "=== VM-Start: Phase 1 — SDDM stoppen ==="
    systemctl stop display-manager
    sleep 2

    # Alle verbleibenden Prozesse killen die nvidia-Devices halten
    for dev in /dev/dri/card1 /dev/nvidia0 /dev/nvidiactl /dev/nvidia-modeset; do
      fuser -k "$dev" 2>/dev/null || true
    done
    sleep 2

    log "Phase 2: nvidia-Module entladen"
    modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
    if lsmod | grep -q "^nvidia "; then
      log "lsmod nvidia noch aktiv:"
      lsmod | grep nvidia | logger -t vm-start
      abort "nvidia-Modul nicht entladbar"
    fi
    log "nvidia-Module OK"

    log "Phase 3: GPU an vfio-pci"
    "$VIRSH" nodedev-detach pci_0000_01_00_0 || abort "GPU-Detach fehlgeschlagen"
    "$VIRSH" nodedev-detach pci_0000_01_00_1 2>/dev/null || true
    log "GPU-Detach OK"

    log "Phase 4: VM starten"
    "$VIRSH" start "$VM_NAME" || abort "VM-Start fehlgeschlagen"
    log "VM gestartet"

    echo "init_linux_after_qemu_start" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
    systemd-inhibit --what=idle:sleep --who="Windows VM" --why="Gaming auf VM" sleep infinity &
    echo $! > /tmp/vm-inhibit.pid

    log "Phase 5: SDDM starten (niri ohne nvidia)"
    systemctl start display-manager

    log "Warte auf niri-Socket..."
    NIRI_SOCK=""
    for i in $(seq 1 60); do
      NIRI_SOCK=$(ls "$USER_RUNTIME"/niri.*.sock 2>/dev/null | head -1)
      [ -n "$NIRI_SOCK" ] && break
      sleep 1
    done
    log "niri bereit: $NIRI_SOCK"

    log "Warte auf Windows-Boot ($BOOT_WAIT s)..."
    sleep "$BOOT_WAIT"

    log "Phase 6: Looking Glass starten"
    sudo -u "$USER_NAME" \
      NIRI_SOCKET="$NIRI_SOCK" \
      XDG_RUNTIME_DIR="$USER_RUNTIME" \
      WAYLAND_DISPLAY=wayland-1 \
      /run/current-system/sw/bin/niri msg action spawn -- \
        ${pkgs.looking-glass-client}/bin/looking-glass-client \
        -F -f /dev/kvmfr0 \
        win:size=2560x1440 win:dontUpscale=on \
        input:captureOnFocus=no input:grabKeyboardOnFocus=no \
        input:escapeKey=KEY_PAUSE \
        win:requestActivation=no \
        spice:enable=no \
        >> /tmp/looking-glass.log 2>&1
    log "Looking Glass gestartet"

    log "Phase 7: VM-Watcher aktiv (warte auf VM-Stop)"
    while "$VIRSH" domstate "$VM_NAME" 2>/dev/null | grep -q "running"; do
      sleep 5
    done
    log "VM gestoppt — Cleanup"

    echo "force_linux" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
    pkill -f looking-glass-client 2>/dev/null || true
    kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
    rm -f /tmp/vm-inhibit.pid

    log "Phase 8: SDDM stoppen für GPU-Reattach"
    systemctl stop display-manager
    sleep 2

    log "Phase 9: GPU zurück an nvidia"
    "$VIRSH" nodedev-reattach pci_0000_01_00_1 2>/dev/null || true
    "$VIRSH" nodedev-reattach pci_0000_01_00_0 || log "WARN: GPU-Reattach fehlgeschlagen"
    modprobe nvidia_modeset nvidia_drm || log "WARN: nvidia-Module nicht ladbar"

    log "Phase 10: SDDM starten (niri mit nvidia)"
    systemctl start display-manager

    log "=== VM-Session beendet ==="
  '';
in
{
  home.packages = with pkgs; [
    looking-glass-client
    scream
    (writeShellScriptBin "vm" ''
      VM_NAME="windows11"

      ACTION="''${1:-}"
      if [ -z "$ACTION" ]; then
        ACTION=$(${pkgs.gum}/bin/gum choose "start" "stop" "pause" "resume" "status" --header="Wähle eine Aktion für die Windows 11 VM:")
        if [ -z "$ACTION" ]; then
          exit 0
        fi
      fi

      case "$ACTION" in
        start)
          echo "=== VM starten ==="

          # USB-Geräte prüfen
          echo "USB-Geräte prüfen..."
          USB_MISSING=0
          check_usb() {
            local vid="$1" pid="$2" name="$3"
            if ${pkgs.usbutils}/bin/lsusb -d "$vid:$pid" > /dev/null 2>&1; then
              echo "  [OK]    $name ($vid:$pid)"
            else
              echo "  [FEHLT] $name ($vid:$pid)"
              USB_MISSING=1
            fi
          }
          check_usb "054c" "0ce6" "Sony DualSense Controller"
          check_usb "16d0" "12f7" "Azeron Keypad"
          if [ "$USB_MISSING" = 1 ]; then
            echo "Fehler: Nicht alle USB-Geräte angeschlossen."
            exit 1
          fi

          # Festplatten unmounten
          echo "Festplatten unmounten..."
          for dev in /dev/sdb1 /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3 /dev/nvme0n1p4; do
            if mountpoint -q "$(findmnt -n -o TARGET "$dev" 2>/dev/null)" 2>/dev/null; then
              sudo umount "$dev" && echo "  $dev unmounted"
            fi
          done

          # Rocket League darf nicht laufen
          if pgrep -f "RocketLeague|Sugar\.exe" >/dev/null 2>&1; then
            echo "Fehler: Rocket League läuft noch. Bitte erst beenden."
            exit 1
          fi

          # sudo-Credentials cachen (wird im Hintergrundprozess gebraucht)
          sudo -v || { echo "Fehler: sudo auth fehlgeschlagen"; exit 1; }

          echo ""
          echo "=== Desktop wird kurz neu gestartet (~5s schwarz) ==="
          echo "Looking Glass erscheint automatisch nach ca. 30 Sekunden."
          echo "Log: journalctl -t vm-start -f"
          echo ""

          # Im Hintergrund starten (überlebt niri-Neustart via disown)
          sudo bash ${vmStartBg} &
          disown $!
          ;;

        stop)
          echo "=== VM beenden ==="

          pkill -f looking-glass-client 2>/dev/null && echo "Looking Glass beendet"
          kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
          rm -f /tmp/vm-inhibit.pid

          if sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
            echo "VM herunterfahren..."
            sudo virsh shutdown "$VM_NAME"
            for i in $(seq 1 60); do
              if ! sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
                echo "VM ist aus."
                break
              fi
              sleep 1
            done
            if sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
              echo "VM reagiert nicht, erzwinge Shutdown..."
              sudo virsh destroy "$VM_NAME"
            fi
          else
            echo "VM ist bereits aus."
          fi

          echo "force_linux" > /tmp/vm-toggle-kbd.fifo
          echo "(Hintergrundprozess übernimmt GPU-Reattach und SDDM-Neustart)"
          echo "=== VM wird beendet ==="
          ;;

        pause)
          echo "=== VM pausieren ==="
          pkill -f looking-glass-client 2>/dev/null && echo "Looking Glass beendet"
          sudo virsh suspend "$VM_NAME"
          echo "=== VM pausiert ==="
          ;;

        resume)
          echo "=== VM fortsetzen ==="
          sudo virsh resume "$VM_NAME"
          NIRI_SOCK=$(ls /run/user/1000/niri.*.sock 2>/dev/null | head -1)
          if [ -n "$NIRI_SOCK" ]; then
            NIRI_SOCKET="$NIRI_SOCK" niri msg action spawn -- \
              looking-glass-client -F -f /dev/kvmfr0 \
              win:size=2560x1440 win:dontUpscale=on \
              input:captureOnFocus=no input:grabKeyboardOnFocus=no \
              input:escapeKey=KEY_PAUSE \
              win:requestActivation=no \
              spice:enable=no
          else
            looking-glass-client -F -f /dev/kvmfr0 \
              win:size=2560x1440 win:dontUpscale=on \
              input:captureOnFocus=no input:grabKeyboardOnFocus=no \
              input:escapeKey=KEY_PAUSE \
              win:requestActivation=no \
              spice:enable=no \
              > /tmp/looking-glass.log 2>&1 &
          fi
          echo "=== VM läuft wieder ==="
          ;;

        status)
          sudo virsh domstate "$VM_NAME"
          ;;

        fixcon)
          echo "=== Controller neu verbinden ==="
          if ! sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q running; then
            echo "VM ist nicht aktiv."
            exit 1
          fi
          sudo virsh detach-device "$VM_NAME" "${controllerXml}" 2>/dev/null || true
          sleep 1
          sudo virsh attach-device "$VM_NAME" "${controllerXml}"
          echo "=== Controller verbunden ==="
          ;;

        *)
          echo "Verwendung: vm {start|stop|pause|resume|fixcon|status}"
          ;;
      esac
    '')
  ];

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
}
