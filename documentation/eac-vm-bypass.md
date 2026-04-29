# Easy Anti-Cheat (EAC) VM-Erkennung umgehen — NixOS / libvirt / QEMU

Erstellt: 2026-04-28

## Überblick

Easy Anti-Cheat (EAC) blockiert Spiele, wenn es erkennt, dass es in einer virtuellen Maschine läuft.
Die Fehlermeldung lautet: **"Läuft nicht auf virtueller Maschine"** (bzw. "Cannot run under virtual machine").

Diese Dokumentation beschreibt alle Erkennungsvektoren, warum jeder einzelne auslöst, und was
konkret geändert wurde, damit EAC unter KVM/QEMU/libvirt auf NixOS funktioniert.

Getestet mit: Rocket League (EAC), NixOS unstable, libvirt + QEMU 10.2, OVMF/EDK2.

---

## Erkennungsvektoren — was EAC prüft

EAC operiert als Kernel-Level-Treiber und kann viele verschiedene Hinweise auf eine VM auswerten.
Die wichtigsten Vektoren und ihr Status in diesem Setup:

| Erkennungsvektor | Beschreibung | Status nach Fix |
|---|---|---|
| CPUID Hypervisor-Bit | Bit 31 in CPUID Leaf 1 ECX zeigt "läuft unter Hypervisor" | ✓ Versteckt via `kvm:hidden` |
| Hyper-V CPUID Leaves | Leaf 0x40000000+ enthüllt Hypervisor-Vendor und -Fähigkeiten | ✓ Entfernt (kein `<hyperv>`) |
| SMBIOS Type 1 Hersteller | Ohne Spoofing steht "QEMU" in Systemhersteller/Modell | ✓ Spoofed auf ASUS ROG |
| SMBIOS Type 0 BIOS-Vendor | OVMF/EDK2 kodiert "BOCHS" hart in die Firmware | ✓ Binary-Patch: BOCHS → ALASKA |
| Netzwerkkarten-OUI | QEMU generiert MACs mit `52:54:00:xx:xx:xx` (bekanntes QEMU-OUI) | ✓ Intel-OUI `b4:96:91:...` |
| Netzwerkkartentyp | VirtIO-NIC erscheint als "Red Hat VirtIO Ethernet Adapter" | ✓ Geändert auf e1000e |
| VMware Backdoor Port | VMware-kompatibler I/O-Port (detectierbar) | ✓ Deaktiviert (`vmport=off`) |

---

## Was NICHT geholfen hat / Sackgassen

### 1. `libvirt sysinfo <bios>` überschreibt OVMF nicht

Ursprünglich versucht:

```xml
<sysinfo type="smbios">
  <bios>
    <entry name="vendor">American Megatrends International, LLC.</entry>
    ...
  </bios>
</sysinfo>
```

**Ergebnis**: Das Datum (14.11.2023) wurde korrekt übernommen, aber der BIOS-Vendor blieb "BOCHS".
**Ursache**: Bei UEFI-VMs (OVMF/EDK2) baut die Firmware ihre eigene SMBIOS-Type-0-Tabelle auf und
schreibt den Vendor-String direkt in das Binary. libvirts `sysinfo`-Überschreibung greift für
SMBIOS Type 1 (Systeminfo), aber nicht zuverlässig für Type 0 (BIOS-Info) unter OVMF.

### 2. `virtualisation.libvirtd.qemu.ovmf.packages` existiert in NixOS nicht mehr

Versuch, ein gepatchtes OVMF-Paket via NixOS-Option einzuhängen:

```nix
virtualisation.libvirtd.qemu.ovmf.packages = [ patchedOvmf ];
```

**Ergebnis**: Build-Fehler:
```
Failed assertions:
- The 'virtualisation.libvirtd.qemu.ovmf' submodule has been removed.
  All OVMF images distributed with QEMU are now available by default.
```

**Ursache**: In neueren NixOS-Versionen wurde diese Option entfernt. OVMF kommt jetzt direkt aus
dem QEMU-Paket (`${pkgs.qemu}/share/qemu/`). Eine direkte Paket-Konfiguration ist nicht mehr möglich.

**Lösung**: Activation Script (siehe unten).

### 3. QEMU enthält kein `edk2-x86_64-vars.fd`

Beim Wechsel auf einen manuellen OVMF-Pfad (`/var/lib/libvirt/ovmf/`) braucht libvirt ein
VARS-Template, um das NVRAM der VM initial zu befüllen. QEMU liefert für x86_64 jedoch kein
VARS-File mit — nur für ARM, RISC-V etc.

```
# Das existiert NICHT in ${pkgs.qemu}/share/qemu/:
edk2-x86_64-vars.fd  ← fehlt!

# Das existiert:
edk2-x86_64-code.fd
edk2-x86_64-secure-code.fd
edk2-arm-vars.fd     ← nur andere Architekturen
edk2-i386-vars.fd
```

**Lösung**: VARS-Template aus `pkgs.OVMF.fd` (`/FV/OVMF_VARS.fd`) kopieren.

### 4. `<ioapic driver="acpi"/>` ist kein gültiger Wert

Beim Entfernen der Hyper-V-Features wurde `driver="kvm"` fälschlicherweise auf `driver="acpi"`
geändert. libvirt akzeptiert nur `kvm` oder `qemu` als Werte.

**Fix**: Zurück auf `driver="kvm"` — das ist unabhängig von Hyper-V-Features.

### 5. `virsh undefine --nvram` löscht das VM-NVRAM unwiederbringlich

Beim Neudefinieren der VM mit `--nvram` wird die UEFI-Variablendatei
(`/var/lib/libvirt/qemu/nvram/windows11_VARS.fd`) gelöscht. Da kein x86_64 VARS-Template in
QEMU mehr vorhanden ist, kann libvirt kein neues NVRAM erstellen → VM startet nicht.

**Lösung**: VARS-Template manuell bereitstellen (siehe Activation Script).

---

## Die funktionierenden Fixes im Detail

### Fix 1: KVM-Hypervisor-Bit verstecken

**Datei**: `vm/windows11.xml`

```xml
<kvm>
  <hidden state="on"/>
</kvm>
```

**Was es macht**: Setzt Bit 31 in CPUID Leaf 1 ECX auf 0. Ohne diesen Fix würde jedes Programm,
das `CPUID` ausführt, sofort sehen dass ein Hypervisor aktiv ist.

**Wichtig**: Das versteckt nur das KVM-spezifische Hypervisor-Bit. Hyper-V CPUID-Leaves
(0x40000000+) sind davon getrennt — deshalb war das alleine nicht ausreichend.

---

### Fix 2: Hyper-V-Features komplett entfernen

**Datei**: `vm/windows11.xml`

**Vorher** (nicht funktionsfähig):
```xml
<hyperv mode="custom">
  <relaxed state="on"/>
  <vapic state="on"/>
  <spinlocks state="on" retries="8191"/>
  <vendor_id state="on" value="GenuineIntel"/>
</hyperv>
```

**Nachher** (funktionsfähig):
```xml
<!-- Kein <hyperv> Block mehr -->
```

**Warum das der Hauptauslöser war**:

Sobald Hyper-V-Features aktiviert sind, existieren CPUID-Leaves ab 0x40000000. Diese sind die
standardisierte Hypervisor-Schnittstelle. Mit `<kvm><hidden>` wird nur Leaf 1 Bit 31 geleert,
aber die Hyper-V-Leaves bleiben vollständig sichtbar.

Der Ablauf der Erkennung:
1. EAC führt `CPUID` mit Leaf `0x40000000` aus
2. Ohne Hyper-V-Features: Rückgabe = 0 (kein Hypervisor vorhanden)
3. Mit Hyper-V-Features: Rückgabe = Hypervisor-Vendor-String in EBX/ECX/EDX

Selbst mit `vendor_id = "GenuineIntel"` (statt "KVMKVMKVM") signalisiert die bloße Existenz
von Leaf 0x40000000 einer Anti-Cheat-Lösung, dass CPUID-Hypervisor-Leaves vorhanden sind.

**Erkennbarer Beweis im Screenshot**: Windows zeigte in `msinfo32` ganz unten:
> "Es wurde ein Hypervisor erkannt. Für die Ausführung von Hyper-V erforderliche Funktionen
> werden nicht angezeigt."

Nach dem Entfernen der Hyper-V-Features verschwindet diese Zeile komplett.

**Folgeänderung**: `<timer name="hypervclock">` ebenfalls entfernt, da dieser Timer nur mit
Hyper-V-Enlightenments Sinn macht:

```xml
<!-- Entfernt: -->
<timer name="hypervclock" present="yes"/>
```

---

### Fix 3: SMBIOS Type 1 Spoofing (Systemhersteller)

**Datei**: `vm/windows11.xml`

```xml
<os>
  ...
  <smbios mode="sysinfo"/>
</os>

<sysinfo type="smbios">
  <bios>
    <entry name="vendor">American Megatrends International, LLC.</entry>
    <entry name="date">11/14/2023</entry>
    <entry name="release">1.8</entry>
  </bios>
  <system>
    <entry name="manufacturer">ASUS</entry>
    <entry name="product">ROG STRIX Z790-E GAMING WIFI</entry>
    <entry name="version">1.0</entry>
    <entry name="serial">To Be Filled By O.E.M.</entry>
    <entry name="family">To Be Filled By O.E.M.</entry>
  </system>
  <baseBoard>
    <entry name="manufacturer">ASUSTeK COMPUTER INC.</entry>
    <entry name="product">ROG STRIX Z790-E GAMING WIFI</entry>
    <entry name="version">Rev 1.xx</entry>
    <entry name="serial">To Be Filled By O.E.M.</entry>
  </baseBoard>
  <chassis>
    <entry name="manufacturer">Default string</entry>
    <entry name="version">Default string</entry>
    <entry name="serial">Default string</entry>
    <entry name="asset">Default string</entry>
    <entry name="sku">Default string</entry>
  </chassis>
</sysinfo>
```

**Was es macht**: Überschreibt SMBIOS Type 1 (System Information) und Type 2 (Baseboard).
Ohne Spoofing steht unter Windows → `msinfo32` → Systemhersteller: **"QEMU"**.
Mit Spoofing steht dort: **"ASUS"** / "ROG STRIX Z790-E GAMING WIFI".

**Wichtig**: `<smbios mode="sysinfo"/>` im `<os>`-Block ist zwingend notwendig, damit
libvirt die sysinfo-Daten auch tatsächlich an QEMU übergibt.

**Was es NICHT überschreibt**: SMBIOS Type 0 (BIOS Vendor "BOCHS") — dafür ist der
Binary-Patch (Fix 4) notwendig.

---

### Fix 4: OVMF Binary-Patch (BOCHS → ALASKA)

**Datei**: `vm/gpu-passthrough.nix`

```nix
system.activationScripts.patchOvmf.text = ''
  mkdir -p /var/lib/libvirt/ovmf

  # CODE: aus QEMU kopieren und BOCHS-Strings patchen
  install -m644 ${pkgs.qemu}/share/qemu/edk2-x86_64-secure-code.fd \
    /var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd
  ${pkgs.python3}/bin/python3 -c "
f = '/var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd'
data = open(f, 'rb').read()
data = data.replace(b'BOCHS ', b'ALASKA')
data = data.replace(b'BXPC', b'AMI ')
open(f, 'wb').write(data)
"

  # VARS-Template: QEMU hat kein x86_64 vars-file, OVMFFull wird genutzt.
  # Nur beim ersten Mal kopieren — danach enthält die Datei VM-UEFI-Zustand.
  if [ ! -f /var/lib/libvirt/ovmf/OVMF_VARS.fd ]; then
    install -m644 ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd /var/lib/libvirt/ovmf/OVMF_VARS.fd
  fi
'';
```

**Warum Binary-Patch statt Quell-Patch**:

Die Strings "BOCHS " und "BXPC" sind im EDK2-Quellcode (`OvmfPkg/SmbiosPlatformDxe/`) und in
den ACPI-Tabellen fest kodiert. OVMF baut seine eigenen SMBIOS-Tabellen beim Start auf und
überschreibt dabei, was libvirt via `sysinfo` übergibt. Der einzige Weg ohne OVMF-Neukompilierung
ist ein direkter Patch am Binary.

**Warum Activation Script statt `qemu.ovmf.packages`**:

Die NixOS-Option `virtualisation.libvirtd.qemu.ovmf.packages` wurde entfernt. Das Activation
Script läuft bei jedem `nixos-rebuild switch` und kopiert + patcht die Datei neu. Der Code-File
wird dabei immer aktualisiert (neue QEMU-Version → neues Binary → neu patchen). Das VARS-File
wird nur beim allerersten Mal erstellt, um den UEFI-Zustand (Boot-Einträge, Secure-Boot-Keys)
nicht bei jedem Rebuild zu überschreiben.

**Byte-Sicherheit**: Der Patch ersetzt immer gleich lange Strings:
- `BOCHS ` (6 Bytes) → `ALASKA` (6 Bytes) ✓
- `BXPC` (4 Bytes) → `AMI ` (4 Bytes) ✓

Die Firmware-Struktur bleibt intakt.

**Loader-Pfad** in der VM XML zeigt auf die gepatchte Datei:
```xml
<loader readonly="yes" secure="yes" type="pflash">
  /var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd
</loader>
<nvram template="/var/lib/libvirt/ovmf/OVMF_VARS.fd">
  /var/lib/libvirt/qemu/nvram/windows11_VARS.fd
</nvram>
```

Das `<nvram template="...">` ist notwendig, weil libvirt bei einem benutzerdefinierten
Loader-Pfad nicht automatisch weiß, welches VARS-File als Template verwendet werden soll.
Die Angabe des Templates ist nur relevant wenn `/var/lib/libvirt/qemu/nvram/windows11_VARS.fd`
noch nicht existiert (Erststart).

**Überprüfung ob der Patch wirkt**:
```bash
strings /var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd | grep -i bochs
# → Keine Ausgabe = Patch erfolgreich
```

---

### Fix 5: Netzwerkkarte — Modell und MAC

**Datei**: `vm/windows11.xml`

**Vorher**:
```xml
<interface type="network">
  <source network="default"/>
  <model type="virtio"/>
</interface>
```

**Nachher**:
```xml
<interface type="network">
  <mac address="b4:96:91:4a:f3:c2"/>
  <source network="default"/>
  <model type="e1000e"/>
</interface>
```

**Zwei Änderungen**:

1. **Modell `virtio` → `e1000e`**: Die VirtIO-NIC meldet sich in Windows als
   "Red Hat VirtIO Ethernet Adapter" — ein eindeutiger VM-Hinweis. Die e1000e ist eine
   echte Intel-Netzwerkkarte (Gigabit), die auch in physischen Systemen vorkommt.

2. **MAC-Adresse mit Intel-OUI**: QEMU generiert standardmäßig MACs mit dem Präfix
   `52:54:00:xx:xx:xx`. Dieser OUI (Organizationally Unique Identifier) ist speziell für
   QEMU/KVM registriert und für Anti-Cheat erkennbar. `b4:96:91:...` ist ein echtes Intel-OUI
   (registriert auf Intel Corporate), wie es auf physischen Mainboards vorkommt.

**Hinweis zur Performance**: Die e1000e ist langsamer als VirtIO. Für Gaming (primär GPU-lastig)
ist der Unterschied vernachlässigbar. Falls nötig: Im laufenden Betrieb via `virsh` auf VirtIO
wechseln und testen ob EAC dann noch blockiert.

---

### Fix 6: SMM für Secure Boot aktivieren

**Datei**: `vm/windows11.xml`

```xml
<features>
  ...
  <smm state="on"/>
  ...
</features>
```

**Warum nötig**: Wenn ein manueller Loader-Pfad (außerhalb von `/run/libvirt/nix-ovmf/`)
verwendet wird, validiert libvirt strikter. Secure Boot (`secure="yes"` im `<loader>`) erfordert
dann explizit `<smm state="on"/>`, sonst:
```
error: unsupported configuration: Secure boot requires SMM feature enabled
```

SMM (System Management Mode) ist eine spezielle CPU-Betriebsart, die UEFI Secure Boot für
sichere Ausführung benötigt.

---

## Zusammenfassung aller Änderungen

### `vm/windows11.xml`

| Abschnitt | Änderung |
|---|---|
| `<os>` | `<smbios mode="sysinfo"/>` hinzugefügt |
| `<os>` | Loader-Pfad → `/var/lib/libvirt/ovmf/edk2-x86_64-secure-code.fd` |
| `<os>` | `<nvram template="...">` hinzugefügt |
| `<sysinfo>` | Komplett neu: ASUS-Hersteller, AMI BIOS-Vendor, Baseboard-Info |
| `<features>` | `<smm state="on"/>` hinzugefügt |
| `<features>` | Kompletter `<hyperv>` Block entfernt |
| `<clock>` | `<timer name="hypervclock">` entfernt |
| `<interface>` | `model="virtio"` → `model="e1000e"` |
| `<interface>` | `<mac address="b4:96:91:4a:f3:c2"/>` hinzugefügt |

### `vm/gpu-passthrough.nix`

| Änderung | Zweck |
|---|---|
| `system.activationScripts.patchOvmf` hinzugefügt | OVMF patchen + VARS-Template bereitstellen |

---

## VM nach XML-Änderungen neu definieren

Nach jeder Änderung an `windows11.xml` muss die VM neu definiert werden:

```bash
# VM stoppen (falls läuft)
sudo virsh destroy windows11 2>/dev/null

# WICHTIG: --nvram nur verwenden wenn das NVRAM wirklich weg soll!
# Ohne --nvram bleibt der UEFI-Zustand (Boot-Einträge, Secure Boot Keys) erhalten.
sudo virsh undefine windows11          # NVRAM behalten
# ODER:
sudo virsh undefine windows11 --nvram  # NVRAM löschen (nur wenn nötig)

# Neu definieren
sudo virsh define /home/leonardn/nixos-config/vm/windows11.xml

# Starten
vm start
```

**Wann `--nvram` notwendig ist**:
- Wenn der Loader-Pfad geändert wird (anderes OVMF-File)
- Wenn UEFI-Einstellungen zurückgesetzt werden sollen

**Wann `--nvram` vermieden werden sollte**:
- Bei normalen Feature-Änderungen (CPU, RAM, Geräte)
- Das NVRAM enthält Boot-Einträge, Windows-Secure-Boot-Keys und EFI-Variablen — alles geht verloren

---

## Verifikation dass alles funktioniert

In Windows `msinfo32` öffnen (`Win+R` → `msinfo32`) und prüfen:

| Feld | Soll-Wert | Bedeutung |
|---|---|---|
| Systemhersteller | ASUS | SMBIOS Type 1 Spoofing funktioniert |
| Systemmodell | ROG STRIX Z790-E GAMING WIFI | SMBIOS Type 1 Spoofing funktioniert |
| BIOS-Version/-Datum | ALASKA - ... | OVMF Binary-Patch funktioniert |
| Unten: "Hypervisor erkannt" | Nicht vorhanden | Hyper-V Leaves entfernt |

---

## Was bei zukünftigen QEMU-Updates passiert

Der Activation Script patcht bei **jedem** `nixos-rebuild switch` das OVMF-Binary neu:

```
QEMU-Update → neues edk2-x86_64-secure-code.fd → Activation Script patcht es → fertig
```

Es muss nichts manuell gemacht werden. Das VARS-File bleibt unberührt (durch die
`if [ ! -f ... ]`-Bedingung), sodass UEFI-Einstellungen beim Update erhalten bleiben.

---

## Bekannte Einschränkungen nach dem Fix

1. **Keine Hyper-V-Enlightenments**: Durch das Entfernen der Hyper-V-Features fehlen einige
   Windows-Optimierungen (z.B. Paravirtualisierung für Scheduling, Speicher). Für Gaming
   ist das in der Praxis kaum messbar, da die GPU der Flaschenhals ist.

2. **Kein `hypervclock`**: Windows nutzt jetzt den normalen `rtc`-Timer statt dem präziseren
   Hyper-V-Clock. In seltenen Fällen kann das leichte Timer-Drift verursachen, aber für
   Gaming irrelevant.

3. **e1000e statt VirtIO NIC**: Geringfügig schlechtere Netzwerk-Performance. Für Gaming
   (Latenz wichtiger als Durchsatz) praktisch kein Unterschied.

4. **BOCHS in ACPI-Tabellen**: QEMU schreibt "BOCHS" und "BXPC" auch als OEM-ID in ACPI-Tabellen.
   Diese wurden NICHT gepatcht (komplexer als OVMF-Patch). Aktuelle EAC-Version prüft das
   offenbar nicht — falls in Zukunft nötig, gibt es dafür separate QEMU-Commandline-Args
   (`-machine oem-id=...`).
