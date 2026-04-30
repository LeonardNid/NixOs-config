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
        ENTRY=$(sudo ls /boot/loader/entries/ 2>/dev/null | grep "specialisation-gpuvm" | sort -V | tail -1 | sed 's/\.conf$//')
        if [ -z "$ENTRY" ]; then
          echo "Fehler: gpuvm-Bootentry nicht gefunden in /boot/loader/entries/"
          echo "Verfügbare Entries:"
          sudo ls /boot/loader/entries/ | grep nixos
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
      echo "Modus:       gpuvm (GPU-Passthrough)"
      echo "GPU-Treiber: $DRIVER"
    else
      echo "Modus:       gpulinux (PRIME Offload)"
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
      BOOT_DELAY=30
      RESUME_DELAY=2

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

          # GPU-Modus prüfen (nur im gpuvm-Modus startet die VM)
          GPU_DRIVER=$(readlink /sys/bus/pci/devices/0000:01:00.0/driver 2>/dev/null | xargs basename 2>/dev/null || echo "keiner")
          if [ "$GPU_DRIVER" != "vfio-pci" ]; then
            echo ""
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
            echo ""
            echo "Fehler: Nicht alle USB-Geräte angeschlossen. VM wird nicht gestartet."
            exit 1
          fi

          # Festplatten unmounten
          echo "Festplatten unmounten..."
          for dev in /dev/sdb1 /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3 /dev/nvme0n1p4; do
            if mountpoint -q "$(findmnt -n -o TARGET "$dev" 2>/dev/null)" 2>/dev/null; then
              sudo umount "$dev" && echo "  $dev unmounted"
            fi
          done

          # VM starten
          echo "VM starten..."
          if ! sudo virsh start "$VM_NAME"; then
            echo ""
            echo "Fehler: VM konnte nicht gestartet werden."
            exit 1
          fi

          sleep 0.5
          echo "init_linux_after_qemu_start" > /tmp/vm-toggle-kbd.fifo

          sleep 2

          systemd-inhibit --what=idle:sleep --who="Windows VM" --why="Gaming auf VM" sleep infinity &
          echo $! > /tmp/vm-inhibit.pid

          # Fortschrittsbalken während Windows bootet
          echo "=== Windows bootet... (ScrollLock = Input umschalten) ==="
          for i in $(seq 1 $BOOT_DELAY); do
            filled=$(( i * 30 / BOOT_DELAY ))
            empty=$(( 30 - filled ))
            bar=$(printf '%0.s█' $(seq 1 $filled) 2>/dev/null)$(printf '%0.s░' $(seq 1 $empty) 2>/dev/null)
            printf '\r[%s] %d/%ds' "$bar" "$i" "$BOOT_DELAY"
            sleep 1
          done
          echo ""

          # Looking Glass starten
          echo "Looking Glass starten..."
          if [ "$XDG_CURRENT_DESKTOP" = "niri" ]; then
            niri msg action focus-monitor-left
            sleep 0.3
          fi
          looking-glass-client -F -f /dev/kvmfr0 \
            win:size=2560x1440 win:dontUpscale=on \
            input:captureOnFocus=no input:grabKeyboardOnFocus=no \
            input:escapeKey=KEY_PAUSE \
            win:requestActivation=no \
            spice:enable=no \
            > /tmp/looking-glass.log 2>&1 &
          LG_PID=$!

          # Background-Watcher: räumt auf wenn VM stoppt
          (while sudo virsh domstate "$VM_NAME" 2>/dev/null | grep -q "running"; do
            sleep 5
          done
          echo "force_linux" > /tmp/vm-toggle-kbd.fifo
          pkill -f looking-glass-client 2>/dev/null
          kill "$(cat /tmp/vm-inhibit.pid 2>/dev/null)" 2>/dev/null
          rm -f /tmp/vm-inhibit.pid
          notify-send "Windows VM" "VM gestoppt, aufgeräumt." 2>/dev/null || true) &

          echo "Looking Glass läuft (PID: $LG_PID)"
          echo "Log: /tmp/looking-glass.log"
          echo ""
          echo "=== VM läuft! ScrollLock = Input umschalten ==="
          echo "VM stoppt automatisch wenn Windows herunterfährt."
          echo "Oder manuell: vm stop"
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
          echo "=== Fertig ==="
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
          if [ "$XDG_CURRENT_DESKTOP" = "niri" ]; then
            niri msg action focus-monitor-left
            sleep 0.3
          fi
          looking-glass-client -F -f /dev/kvmfr0 \
            win:size=2560x1440 win:dontUpscale=on \
            input:captureOnFocus=no input:grabKeyboardOnFocus=no \
            input:escapeKey=KEY_PAUSE \
            win:requestActivation=no \
            spice:enable=no \
            > /tmp/looking-glass.log 2>&1 &
          echo "Looking Glass gestartet (PID: $!)"
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
