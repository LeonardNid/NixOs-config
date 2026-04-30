{ pkgs, ... }:

let
  gpuHookScript = pkgs.writeShellScript "libvirt-qemu-hook" ''
    VM_NAME="$1"
    OPERATION="$2"
    PHASE="$3"

    if [ "$VM_NAME" != "windows11" ] || [ "$OPERATION/$PHASE" != "release/end" ]; then
      exit 0
    fi

    log() { logger -t libvirt-gpu-hook "$*"; }

    log "release/end: GPU zurück an nvidia"

    # GPU von vfio-pci trennen und an nvidia zurückbinden
    for dev in 0000:01:00.0 0000:01:00.1; do
      driver_path="/sys/bus/pci/devices/$dev/driver"
      if [ -e "$driver_path" ]; then
        log "Unbind $dev"
        echo "$dev" > "/sys/bus/pci/drivers/vfio-pci/unbind" 2>/dev/null || true
      fi
      echo "" > "/sys/bus/pci/devices/$dev/driver_override" 2>/dev/null || true
    done

    echo "0000:01:00.0" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null \
      && log "nvidia bind OK" \
      || log "WARN: nvidia bind fehlgeschlagen — Reboot nötig"

    echo "0000:01:00.1" > /sys/bus/pci/drivers/snd_hda_intel/bind 2>/dev/null \
      || log "WARN: snd_hda_intel bind fehlgeschlagen"

    if /run/current-system/sw/bin/nvidia-smi >/dev/null 2>&1; then
      log "nvidia-smi OK"
    else
      log "WARN: nvidia-smi fehlgeschlagen nach VM-Stop"
    fi
  '';
in
{
  environment.etc."libvirt/hooks/qemu" = {
    source = gpuHookScript;
    mode = "0755";
  };
}
