{ pkgs, ... }:

let
  gpuHookScript = pkgs.writeShellScript "libvirt-qemu-hook" ''
    VM_NAME="$1"
    OPERATION="$2"
    PHASE="$3"

    GPU="0000:01:00.0"
    AUDIO="0000:01:00.1"

    log() {
      logger -t libvirt-gpu-hook "$*"
    }

    unbind_device() {
      local dev="$1"
      local driver_path="/sys/bus/pci/devices/$dev/driver"
      if [ -e "$driver_path" ]; then
        log "Unbind $dev von $(readlink -f $driver_path | xargs basename)"
        echo "$dev" > "$driver_path/unbind" || log "WARN: unbind $dev fehlgeschlagen"
      fi
    }

    bind_device() {
      local dev="$1"
      local driver="$2"
      echo "$driver" > "/sys/bus/pci/devices/$dev/driver_override" || log "WARN: driver_override $dev fehlgeschlagen"
      echo "$dev" > "/sys/bus/pci/drivers/$driver/bind" || log "WARN: bind $dev an $driver fehlgeschlagen"
    }

    clear_override() {
      local dev="$1"
      echo "" > "/sys/bus/pci/devices/$dev/driver_override" || log "WARN: clear driver_override $dev fehlgeschlagen"
    }

    if [ "$VM_NAME" != "windows11" ]; then
      exit 0
    fi

    case "$OPERATION/$PHASE" in
      prepare/begin)
        log "GPU-Swap: nvidia → vfio-pci (VM startet)"

        # Pre-Flight: Rocket League darf nicht laufen
        if pgrep -f "RocketLeague|Sugar\.exe" >/dev/null 2>&1; then
          log "ABBRUCH: Rocket League läuft noch (pgrep match)"
          exit 1
        fi

        unbind_device "$GPU"
        unbind_device "$AUDIO"

        bind_device "$GPU"   "vfio-pci"
        bind_device "$AUDIO" "vfio-pci"

        log "GPU-Swap abgeschlossen: beide Devices an vfio-pci"
        ;;

      release/end)
        log "GPU-Swap: vfio-pci → nvidia (VM gestoppt)"

        unbind_device "$GPU"
        unbind_device "$AUDIO"

        clear_override "$GPU"
        clear_override "$AUDIO"

        # GPU an nvidia zurückbinden
        echo "$GPU" > /sys/bus/pci/drivers/nvidia/bind \
          || log "WARN: nvidia bind für $GPU fehlgeschlagen"

        # Audio an snd_hda_intel zurückbinden
        echo "$AUDIO" > /sys/bus/pci/drivers/snd_hda_intel/bind \
          || log "WARN: snd_hda_intel bind für $AUDIO fehlgeschlagen"

        # Verifikation
        if /run/current-system/sw/bin/nvidia-smi >/dev/null 2>&1; then
          log "nvidia-smi OK — GPU zurück unter nvidia"
        else
          log "WARN: nvidia-smi fehlgeschlagen nach VM-Stop — prüfe: journalctl -t libvirt-gpu-hook"
        fi
        ;;
    esac
  '';
in
{
  environment.etc."libvirt/hooks/qemu" = {
    source = gpuHookScript;
    mode = "0755";
  };
}
