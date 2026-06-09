# Mini-PC NixOS-Installation — GMKtec Nucbox M6 Ultra

Erstellt: 2026-06-09

## Übersicht

Ein neuer **GMKtec Nucbox M6 Ultra** wird vom vorinstallierten Windows 11 auf **NixOS**
umgestellt und löst den bisherigen Desktop-Host als Arbeits-/Privatrechner ab. Die Installation
erfolgt **headless über SSH vom Laptop aus** — der Mini-PC bootet den NixOS-Minimal-Installer,
und der gesamte Rest (Partitionieren, Config, `nixos-install`) wird vom Laptop ferngesteuert.

### Motivation

- Der alte Desktop (`leonardn`, i5-14600K + RTX 3080) ist jetzt reiner Windows-Gaming-PC
  (siehe `MOONLIGHT-STREAMING-SETUP.md`)
- Der Mini-PC wird der neue Linux-Desktop — sparsam, leise, eigener Host im Flake

### Hardware

| Komponente | Wert |
|---|---|
| Modell | GMKtec Nucbox M6 Ultra |
| CPU/APU | AMD Ryzen 5 **7640HS** w/ Radeon 760M (Phoenix, RDNA3 iGPU) |
| RAM | 9,5 GiB nutzbar (Rest als UMA-Buffer für die iGPU im BIOS reserviert) |
| SSD | „GMK 512GB" NVMe (476,9 GiB) |
| Boot | UEFI, GPT |

> **Hinweis CPU:** Auf dem Gerät steht teils „7649HS", erkannt wird aber ein **7640HS**.
> Für die Treiber-Wahl egal — beide sind Phoenix-APUs und laufen mit `amdgpu`.

### Eckdaten dieser Installation

| Feld | Wert |
|---|---|
| Hostname | `minipc` |
| Desktop | Niri (Auto-Login) + Noctalia-Shell |
| Tastatur-Layout (Niri) | `neo` (wie alter Desktop) |
| IP im Heimnetz (DHCP) | 192.168.178.62 (eno1, Ethernet) |
| Partitionsschema | 1 GB EFI + 16 GB Swap + Rest ext4 |
| Temp. Passwort (root + leonardn) | `456456` → **nach Erstboot ändern** |

---

## Voraussetzungen

- Ein zweiter NixOS-Rechner (hier: **Laptop**) zum Erstellen des Sticks und Fernsteuern
- USB-Stick ≥ 2 GB (Inhalt wird gelöscht)
- Ethernet-Kabel vom Mini-PC zum Router (DHCP, deutlich einfacher als WLAN im Minimal-Installer)
- Monitor + Tastatur am Mini-PC (nur für BIOS, Kernel-Auswahl, erste Befehle)

---

## 1. Bootfähigen USB-Stick erstellen (auf dem Laptop)

### Gerät identifizieren

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,TRAN
```

Den USB-Stick anhand `TRAN=usb` und Modellname identifizieren (hier `/dev/sda`, „Intenso Speed Line").
**Niemals die interne NVMe (`nvme0n1`) verwenden!**

### Minimal-ISO laden & verifizieren

```bash
cd ~
curl -L --fail -o nixos-minimal-installer.iso \
  https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso

# Prüfsumme gegen offizielle vergleichen
official=$(curl -sL "$(curl -sI https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso \
  | grep -i ^location | tr -d '\r' | awk '{print $2}').sha256")
echo "$official"
sha256sum nixos-minimal-installer.iso
```

Installiert wurde mit `nixos-minimal-26.11pre1011622` (sha256
`b23b81eab44362619f7135a84b352494a95a6701958f1b112a94e5467c6f0268`).

### Auf den Stick schreiben

```bash
# evtl. gemountete Partitionen aushängen
for p in $(lsblk -ln -o NAME,MOUNTPOINT /dev/sda | awk '$2!=""{print $1}'); do sudo umount "/dev/$p"; done

sudo dd if=~/nixos-minimal-installer.iso of=/dev/sda bs=4M conv=fsync oflag=direct status=progress
sync
```

Kontrolle (sollte `iso9660` + `EFIBOOT` zeigen):
```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL /dev/sda
```

---

## 2. Mini-PC vom Stick booten

1. Stick in den Mini-PC stecken.
2. Beim Einschalten wiederholt drücken:
   - Boot-Menü (AMI-BIOS): **`F7`**
   - BIOS-Setup: **`Entf`** oder **`F2`**
3. Im BIOS setzen:
   - **Secure Boot → Disabled** (das Minimal-ISO ist nicht signiert)
   - Boot-Mode: **UEFI**
   - vom USB-Stick booten
4. Im NixOS-Boot-Loader **Kernel `7.0.11`** wählen (neuerer Kernel = bessere Unterstützung der
   frischen AMD-Phoenix-/RDNA3-Hardware). Betrifft nur die Installer-Umgebung.
5. Es erscheint eine Root-Shell: `[root@nixos:~]#`

### Tastatur auf Deutsch

Der Installer startet mit **US-Layout (QWERTY)**:
```bash
loadkeys de
```
> Beim Tippen dieses Befehls sind nur **Y und Z vertauscht** — das „y" in „keys" liegt auf der
> mit „Z" beschrifteten Taste. Danach stimmt das QWERTZ-Layout.

---

## 3. Netzwerk + SSH im Installer (Fernsteuerung vom Laptop)

Am **Mini-PC**:
```bash
ip -brief a            # Ethernet-Interface (eno1) bekommt per DHCP z.B. 192.168.178.62
ping -c2 nixos.org     # Internet prüfen
passwd                 # temporäres ROOT-Passwort setzen (Achtung: root, nicht den nixos-User!)
systemctl start sshd
```

Am **Laptop** den eigenen SSH-Key rüberkopieren (einmalig per Passwort), danach passwortlos:
```bash
# sshpass via nix run, falls nicht installiert
nix run nixpkgs#sshpass -- -p 'PASSWORT' \
  ssh -o StrictHostKeyChecking=no root@192.168.178.62 \
  "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys" < ~/.ssh/id_ed25519.pub

# Test
ssh root@192.168.178.62 'uname -r; grep -m1 "model name" /proc/cpuinfo'
```

> **Fallstrick:** `passwd` setzt das Passwort für den **gerade eingeloggten User**. In der Root-Shell
> ist das root. Wer versehentlich vorher `su nixos` o.ä. macht, setzt das falsche Passwort →
> SSH-Login als root scheitert mit „Permission denied".

---

## 4. (Optional) Windows-OEM-Key sichern

```bash
ssh root@192.168.178.62 'strings /sys/firmware/acpi/tables/MSDM | grep -E "^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$"'
```

> Der ausgelesene Key (`FQGYJ-NHXBD-C3GWY-QYYGV-46Y6G`) ist ein **OEM-Key**, fest in der Firmware
> (MSDM) hinterlegt und **an dieses Mainboard gebunden** — nicht auf ein anderes Gerät übertragbar.
> Gilt aber weiter für eine Neuinstallation von Windows **auf genau diesem Mini-PC** (aktiviert
> sich dann automatisch über die Firmware).

---

## 5. Festplatte partitionieren & formatieren

Löscht Windows komplett. Schema wie auf dem Laptop: **EFI + Swap + ext4-Root**.

```bash
ssh root@192.168.178.62 'set -e
DISK=/dev/nvme0n1
swapoff -a 2>/dev/null || true
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G  -t1:ef00 -c1:BOOT  "$DISK"   # EFI System Partition
sgdisk -n2:0:+16G -t2:8200 -c2:swap  "$DISK"   # Swap
sgdisk -n3:0:0    -t3:8300 -c3:nixos "$DISK"   # Root (Rest)
partprobe "$DISK"; sleep 2
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkswap -L swap /dev/nvme0n1p2
mkfs.ext4 -F -L nixos /dev/nvme0n1p3'
```

Mounten + Swap aktivieren:
```bash
ssh root@192.168.178.62 'set -e
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
swapon /dev/nvme0n1p2'
```

---

## 6. Hardware-Config generieren

```bash
ssh root@192.168.178.62 'nixos-generate-config --root /mnt && cat /mnt/etc/nixos/hardware-configuration.nix'
```

Wichtig für AMD (wird automatisch erkannt):
- `boot.kernelModules = [ "kvm-amd" ]`
- `hardware.cpu.amd.updateMicrocode = lib.mkDefault ...`

---

## 7. Neuen Host im Flake anlegen (auf dem Laptop)

Der bisherige `leonardn`-Host ist auf **Nvidia + GPU-Passthrough + Corsair/Logitech-Daemons**
zugeschnitten. Der Mini-PC bekommt einen **eigenen, schlankeren Host** ohne diesen Ballast.

> **Glücksfall:** `system/hardware.nix` setzt bereits `services.xserver.videoDrivers = [ "amdgpu" ]`
> und `hardware.graphics.enable(32Bit)` — passt für die Radeon 760M direkt, kein extra GPU-Modul nötig.

### a) Hardware-Config übernehmen

```bash
mkdir -p ~/nixos-config/hosts/minipc
scp root@192.168.178.62:/mnt/etc/nixos/hardware-configuration.nix \
  ~/nixos-config/hosts/minipc/hardware-configuration.nix
```

### b) `hosts/minipc/default.nix`

Gespiegelt von `leonardn`, aber **ohne** `nvidia.nix`, `vm/*`, Maus-Daemons, NTFS-Mounts und
GPU-Specialisation:

```nix
{ lib, ... }:

let
  desktop = "niri";          # "kde" oder "niri"
in
{
  imports = [
    ./hardware-configuration.nix
    ../../system/boot.nix
    ../../system/hardware.nix
    ../../system/nix-settings.nix
    ../../system/networking.nix
    ../../system/locale.nix
    ../../system/audio.nix
    ../../system/bluetooth.nix
    ../../system/users.nix
    ../../system/packages.nix
    ../../system/ollama.nix
  ]
  ++ lib.optional (desktop == "kde")  ../../system/desktop.nix
  ++ lib.optional (desktop == "niri") ../../system/niri.nix;

  networking.hostName = "minipc";

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "leonardn";

  home-manager.users.leonardn = {
    _module.args.keyboardLayout = "neo";
    imports = [ ]
      ++ lib.optional (desktop == "niri") ../../home/desktop-niri.nix;
  };
}
```

### c) `flake.nix` ergänzen

```nix
nixosConfigurations.minipc = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit self; };
  modules = [
    ./hosts/minipc
    { home-manager.sharedModules = [ noctalia.homeModules.default ]; }
    niri-flake.nixosModules.niri
  ] ++ homeManagerModules;
};
```

### d) Lokal validieren

Flakes sehen nur git-getrackte Dateien → erst `git add`, dann evaluieren:
```bash
cd ~/nixos-config
git add hosts/minipc flake.nix
nix eval .#nixosConfigurations.minipc.config.system.build.toplevel.drvPath
```
Wenn das eine `…minipc….drv` ausgibt, ist die Config syntaktisch/eval-mäßig in Ordnung.

---

## 8. Repo übertragen & installieren

Repo **ohne `.git`** auf den Mini-PC kopieren (Nix nutzt es dann als reines Path-Flake mit allen
Dateien — kein Commit nötig):

```bash
ssh root@192.168.178.62 'mkdir -p /mnt/root'
rsync -a --delete --exclude='.git' --exclude='result' --exclude='result-*' \
  ~/nixos-config/ root@192.168.178.62:/mnt/root/nixos-config/
```

Installieren (mit niri/noctalia-Caches, ohne interaktiven Root-Passwort-Prompt):

```bash
ssh root@192.168.178.62 'nixos-install --root /mnt --flake /mnt/root/nixos-config#minipc \
  --no-root-passwd \
  --option extra-substituters "https://niri.cachix.org https://noctalia.cachix.org" \
  --option extra-trusted-public-keys "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="'
```

Dauert je nach Cache-Treffern 10–30 Min. Ende: `installation finished!`

---

## 9. Post-Install (Passwörter, Repo ins Home, SSH-Key)

Da mit `--no-root-passwd` installiert wurde, Passwörter per chroot setzen:
```bash
ssh root@192.168.178.62 '
  echo "root:456456"     | nixos-enter --root /mnt -c "chpasswd"
  echo "leonardn:456456" | nixos-enter --root /mnt -c "chpasswd"'
```
> **Wichtig:** Ohne User-Passwort ließe sich z.B. der Sperrbildschirm (swaylock) nicht entsperren.
> Temporär `456456` setzen, nach dem Erstboot mit `passwd` ändern.

Config ins User-Home (wie auf dem Laptop, damit `rebuild` & Co. greifen):
```bash
ssh root@192.168.178.62 '
  cp -a /mnt/root/nixos-config /mnt/home/leonardn/nixos-config
  chown -R 1000:100 /mnt/home/leonardn/nixos-config'
```

Laptop-SSH-Key in den `leonardn`-Account (das installierte System hat `PermitRootLogin no` +
`PasswordAuthentication no` → nur key-basiert als User):
```bash
PUBKEY=$(cat ~/.ssh/id_ed25519.pub)
ssh root@192.168.178.62 "
  mkdir -p /mnt/home/leonardn/.ssh
  echo '$PUBKEY' > /mnt/home/leonardn/.ssh/authorized_keys
  chmod 700 /mnt/home/leonardn/.ssh
  chmod 600 /mnt/home/leonardn/.ssh/authorized_keys
  chown -R 1000:100 /mnt/home/leonardn/.ssh"
```

---

## 10. Reboot — Stolperfalle USB / SquashFS

⚠️ **Den USB-Stick VOR dem Reboot abziehen!** Bleibt er drin, bootet das BIOS wieder den Installer.

Symptom, wenn der Stick während des Installer-Boots abgezogen wird:
```
SQUASHFS error: Unable to read page, block ...
```
Das Live-System liegt als **SquashFS auf dem Stick** — fehlt der Stick, friert der Installer ein.
Das installierte System (ext4 auf der NVMe) hat **kein** SquashFS, dieser Fehler kann dort nie auftreten.

**Vorgehen:**
1. Stick komplett abziehen (alle Ports prüfen).
2. Falls der Installer hängt: **harter Power-Cycle** — Power-Knopf 5–10 s halten bis ganz aus,
   dann wieder einschalten.
3. Ohne Stick bootet das BIOS automatisch die interne SSD (EFI-Eintrag „Linux Boot Manager").
4. Falls nicht: beim Start `F7` → Boot-Menü → internen Eintrag („Linux Boot Manager" /
   „UEFI: GMK 512GB" / NixOS) wählen, **nicht** etwas mit „USB"/„Speed Line".

Nach dem Reboot (neuer SSH-Host-Key!):
```bash
ssh-keygen -R 192.168.178.62
ssh leonardn@192.168.178.62 'hostname; uname -r'   # → minipc
```

---

## 11. Erster Boot: bekannte Probleme & Fixes

### Noctalia-Shell zeigt beim ersten Boot nichts

- **Symptom:** Niri + Wallpaper da, aber keine Bar/Shell. `pgrep quickshell` zeigt den Prozess
  als laufend, keine Fehler im Log.
- **Ursache:** Vermutlich Race beim allerersten Start, während Noctalia seine `settings.json`
  migriert (v27 → v36).
- **Fix (Laufzeit):** Noctalia in der Session neu starten:
  ```bash
  ssh leonardn@192.168.178.62 '
    export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
    pkill -f quickshell; sleep 1
    setsid noctalia-shell >/tmp/noct.log 2>&1 &'
  ```
- Beim nächsten Reboot (Settings bereits migriert) sollte es direkt kommen → noch zu verifizieren.

### `scream`-Dienst crash-loopt

- **Symptom:** Journal voll mit `scream: Invalid interface: virbr0`, Restart im 3-s-Takt.
- **Ursache:** `vm/vm.nix` (über `home/default.nix` für **beide** Hosts geladen) startet einen
  Scream-Audio-Receiver auf `virbr0`. Diese VM-Bridge existiert auf dem Mini-PC nicht.
- **Laufzeit-Stopp:** `systemctl --user stop scream` (kommt beim Reboot wieder).
- **Echter Fix:** siehe TODO — VM-Kram host-spezifisch machen / für `minipc` rausnehmen.

### Monitor-Layout vom alten Desktop

- **Symptom:** Der einzige Monitor (HDMI-A-1) hängt auf Logical-Position `x=2560` — rechts neben
  einem „Phantom"-Monitor (`DP-1`), der am Mini-PC nicht existiert.
- **Ursache:** `home/desktop-niri.nix` hat das Dual-Monitor-Layout des alten Desktops fest verdrahtet
  (`output "DP-1"` @ x=0, `output "HDMI-A-1"` @ x=2560).
- **Echter Fix:** siehe TODO.

---

## 12. Git auf dem Mini-PC einrichten

Die Config wurde beim Installieren nur **als Kopie ohne `.git`** übertragen (Abschnitt 8 — bewusst,
damit Nix sie als Path-Flake nimmt). Damit der `rebuild`-Workflow (git add/commit + nixos-rebuild +
git push) auf dem Mini-PC läuft, braucht er ein echtes Git-Repo mit GitHub-Zugang.

### a) Stand vom Laptop nach GitHub pushen

Der neue `minipc`-Host + Doku werden auf dem **Laptop** committet und gepusht (z. B. via
`rebuild "documentation minipc"`), sodass `origin/main` aktuell ist.

### b) Eigener SSH-Key für den Mini-PC

Pro-Gerät-Key (sauberer als den Laptop-Key zu kopieren — einzeln bei GitHub widerrufbar):

```bash
ssh leonardn@192.168.178.62 'ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "leonardn@minipc"; cat ~/.ssh/id_ed25519.pub'
```

Den ausgegebenen **öffentlichen** Key bei GitHub hinterlegen:
**https://github.com/settings/ssh/new** → Title `minipc`, Key type `Authentication Key`,
Key einfügen → „Add SSH key".

### c) Verbindung testen & frisch klonen

```bash
ssh leonardn@192.168.178.62 '
  ssh -o StrictHostKeyChecking=accept-new -T git@github.com   # → "Hi LeonardNid! ... successfully authenticated"
  rm -rf ~/nixos-config
  git clone git@github.com:LeonardNid/NixOs-config.git ~/nixos-config'
```

> Die alte `.git`-lose Kopie wird dabei ersetzt — da der Mini-PC bereits installiert ist, geht nichts
> verloren. `origin/main` ist die maßgebliche Quelle (und enthält z. B. die Doku, die der Kopie noch fehlte).

Die globale Git-Identität (`user.name`/`user.email`) kommt bereits aus dem Home-Manager-Modul
`home/git.nix`, muss also nicht gesetzt werden. Danach läuft der normale `rebuild`-Workflow
(`$(hostname)` → baut `#minipc`).

---

## 13. Offene Punkte / TODO

- [ ] **Reboot-Test:** kommt Noctalia jetzt von selbst sauber hoch?
- [x] **VM-/Looking-Glass-Kram für `minipc` deaktiviert** (host-spezifisch, nichts gelöscht):
      - `vm/vm.nix` (Looking Glass, scream, `gpu-switch-reboot`, `gpu-status`, `vm`-Befehl,
        Clipboard-Sync) wird **nicht mehr in `home/default.nix`** geladen (das galt für alle
        Hosts), sondern nur noch in `hosts/leonardn/default.nix` importiert.
      - Neues Modul-Arg **`vmTools`** (`_module.args.vmTools`): `true` für `leonardn`,
        `false` für `minipc`. `home/desktop-niri.nix` gated darüber die VM-Clipboard-Autostarts
        (`clipboard-from-vm`/`-to-vm-watch`) und die VM-Waybar-Skripte (`vm-menu` etc.).
      - Ergebnis: auf `leonardn` läuft alles unverändert weiter; auf `minipc` ist der VM-Kram
        nur inaktiv (kein crash-loopender `scream`, keine sinnlosen Clipboard-Prozesse). Alle
        Skripte bleiben im Repo erhalten und sind durch Umlegen des Flags reaktivierbar.
      - Nebeneffekt: behebt denselben `scream`-Crash-Loop auch auf dem **Laptop** (lud `vm.nix`
        ebenfalls über `home/default.nix`).
- [ ] **Monitor-Layout** für den Single-Monitor-Mini-PC korrigieren (Output auf `x=0`), möglichst
      host-spezifisch statt im gemeinsamen `desktop-niri.nix`.
- [x] **Git:** erledigt — `minipc`-Host gepusht, Mini-PC hat eigenen SSH-Key + frischen Clone (Abschnitt 12).
- [ ] **Passwörter** von `456456` auf etwas Eigenes ändern (`passwd`).
- [ ] **Tastatur-Layout** prüfen: aktuell `neo` (wie alter Desktop) — bei Bedarf auf `de` umstellen.
- [ ] **RAM/UMA:** im BIOS prüfen, ob der iGPU-UMA-Buffer kleiner gestellt werden kann (aktuell nur
      9,5 GiB nutzbar).

---

## 14. Getesteter Stand (2026-06-09)

- NixOS installiert, bootet von interner SSD, Auto-Login in Niri
- AMD Radeon 760M via `amdgpu`, Wayland-Rendering ok (swaybg-Wallpaper)
- Ethernet (eno1) per DHCP, SSH key-basiert als `leonardn` erreichbar
- Noctalia-Shell läuft (nach manuellem Neustart) — First-Boot-Verhalten noch zu verifizieren
- Git: `minipc`-Host auf GitHub, Mini-PC mit eigenem SSH-Key frisch geklont — `rebuild` einsatzbereit
- Offen: VM-Kram entfernen, Monitor-Layout (siehe TODO)
