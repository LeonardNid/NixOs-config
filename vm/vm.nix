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

  # Läuft als root im Hintergrund.
  # Voraussetzung: gpuvm-Modus (gpu-switch-reboot → Reboot), dann GPU bereits auf vfio-pci.
  # Kein SDDM-Stop, kein Modul-Entladen — GPU wandert nur zwischen Treibern per Kernel-Param.
  vmStartBg = pkgs.writeShellScript "vm-start-bg" ''
    VM_NAME="windows11"
    VIRSH="${pkgs.libvirt}/bin/virsh"
    BOOT_WAIT=20
    USER_NAME="leonardn"
    USER_ID=1000
    USER_RUNTIME="/run/user/$USER_ID"

    log() { logger -t vm-start "$*"; }

    log "=== VM-Start ==="

    # GPU muss auf vfio-pci sein — nur im gpuvm-Modus (nach gpu-switch-reboot) gegeben
    GPU_DRIVER=$(readlink /sys/bus/pci/devices/0000:01:00.0/driver 2>/dev/null | xargs basename 2>/dev/null || echo "keiner")
    if [ "$GPU_DRIVER" != "vfio-pci" ]; then
      log "FEHLER: GPU ist auf '$GPU_DRIVER', nicht vfio-pci"
      log "Lösung: 'gpu-switch-reboot' ausführen → Reboot → dann 'vm start'"
      exit 1
    fi
    log "GPU auf vfio-pci — OK"

    log "Phase 1: VM starten"
    "$VIRSH" start "$VM_NAME" || { log "VM-Start fehlgeschlagen"; exit 1; }
    log "VM gestartet"

    echo "init_linux_after_qemu_start" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
    systemd-inhibit --what=idle:sleep --who="Windows VM" --why="Gaming auf VM" sleep infinity &
    echo $! > /tmp/vm-inhibit.pid

    log "Warte auf Windows-Boot ($BOOT_WAIT s)..."
    sleep "$BOOT_WAIT"

    log "Phase 2: Looking Glass starten"
    NIRI_SOCK=$(ls "$USER_RUNTIME"/niri.*.sock 2>/dev/null | head -1)
    if [ -n "$NIRI_SOCK" ]; then
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
    else
      log "WARN: kein niri-Socket, Looking Glass nicht gestartet"
    fi

    log "Phase 3: VM-Watcher (warte auf VM-Stop)"
    while "$VIRSH" domstate "$VM_NAME" 2>/dev/null | grep -q "running"; do
      sleep 5
    done
    log "VM gestoppt — Cleanup"

    echo "force_linux" > /tmp/vm-toggle-kbd.fifo 2>/dev/null || true
    pkill -f looking-glass-client 2>/dev/null || true
    kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
    rm -f /tmp/vm-inhibit.pid

    log "=== VM-Session beendet (GPU bleibt auf vfio-pci bis zum nächsten Reboot) ==="
  '';

  # Wechselt zwischen gpulinux (nvidia PRIME) und gpuvm (vfio-pci Passthrough) via Reboot.
  # gpuvm → linux: normaler Reboot. gpulinux → vm: bootctl set-oneshot auf die Specialisation.
  gpuSwitchReboot = pkgs.writeShellScriptBin "gpu-switch-reboot" ''
    CURRENT_MODE="linux"
    grep -q 'gpu_mode=vm' /proc/cmdline && CURRENT_MODE="vm"

    TARGET="''${1:-}"
    if [ -z "$TARGET" ]; then
      [ "$CURRENT_MODE" = "vm" ] && TARGET="linux" || TARGET="vm"
    fi

    case "$TARGET" in
      vm)
        if [ "$CURRENT_MODE" = "vm" ]; then
          echo "Bereits im gpuvm-Modus."
          exit 0
        fi
        ENTRY=$(ls /boot/loader/entries/ 2>/dev/null | grep "specialisation-gpuvm" | sort -V | tail -1 | sed 's/\.conf$//')
        if [ -z "$ENTRY" ]; then
          echo "Fehler: gpuvm-Bootentry nicht gefunden in /boot/loader/entries/"
          echo "Verfügbare Entries:"
          ls /boot/loader/entries/ | grep nixos
          exit 1
        fi
        echo "Wechsel zu gpuvm nach Reboot (Entry: $ENTRY)"
        sudo ${pkgs.systemd}/bin/bootctl set-oneshot "$ENTRY"
        sudo reboot
        ;;
      linux)
        if [ "$CURRENT_MODE" = "linux" ]; then
          echo "Bereits im gpulinux-Modus."
          exit 0
        fi
        echo "Wechsel zu gpulinux nach Reboot..."
        sudo reboot
        ;;
      *)
        echo "Verwendung: gpu-switch-reboot [vm|linux]"
        echo "Aktueller Modus: $CURRENT_MODE"
        exit 1
        ;;
    esac
  '';

  gpuStatus = pkgs.writeShellScriptBin "gpu-status" ''
    if grep -q 'gpu_mode=vm' /proc/cmdline; then
      DRIVER=$(readlink /sys/bus/pci/devices/0000:01:00.0/driver 2>/dev/null | xargs basename 2>/dev/null || echo "unbekannt")
      echo "Modus:      gpuvm (GPU-Passthrough)"
      echo "GPU-Treiber: $DRIVER"
    else
      echo "Modus:      gpulinux (PRIME Offload)"
      echo "GPU-Treiber: nvidia"
    fi
  '';
in
{
  home.packages = with pkgs; [
    looking-glass-client
    scream
    gpuSwitchReboot
    gpuStatus
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

          # GPU-Modus prüfen
          GPU_DRIVER=$(readlink /sys/bus/pci/devices/0000:01:00.0/driver 2>/dev/null | xargs basename 2>/dev/null || echo "keiner")
          if [ "$GPU_DRIVER" != "vfio-pci" ]; then
            echo "Fehler: GPU ist auf '$GPU_DRIVER', nicht vfio-pci."
            echo "Lösung: 'gpu-switch-reboot' ausführen → Reboot → dann 'vm start'"
            exit 1
          fi

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

          sudo -v || { echo "Fehler: sudo auth fehlgeschlagen"; exit 1; }

          echo ""
          echo "Looking Glass erscheint automatisch nach ca. 30 Sekunden."
          echo "Log: journalctl -t vm-start -f"
          echo ""

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
          echo "=== VM beendet (GPU bleibt auf vfio-pci bis zum nächsten Reboot) ==="
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
