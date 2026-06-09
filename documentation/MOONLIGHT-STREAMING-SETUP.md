# Moonlight Streaming Setup — Vollständige Systemdokumentation

Erstellt: 2026-06-06

## Übersicht

Windows Gaming-PC (leonardn Desktop) wird über **Sunshine** (Host) zu einem Stream-Server.
Ein zweiter Rechner (aktuell: Laptop, geplant: Mini-PC) empfängt den Stream mit **Moonlight** (Client).
Die Verbindung läuft über ein **direktes Ethernet-Kabel** zwischen beiden Rechnern für minimalen Jitter.
Der Client-Rechner teilt seine Internetverbindung (WLAN) über das Ethernet mit dem Gaming-PC.

### Motivation

- Spiele mit Anti-Cheat laufen nicht in der VM und sind auf Linux schwer zum Laufen zu bringen
- Kein Monitor-Input-Wechsel, kein Hardware-KVM — nahtloses Wechseln zwischen Gaming und Arbeiten
- Gaming-PC bleibt reiner Windows-PC, Arbeitsrechner bleibt reines Linux

### Geräte

| Rolle | Gerät | OS |
|---|---|---|
| Stream-Host (Gaming) | Desktop-PC (i5-14600K, RTX 3080) | Windows 11 |
| Stream-Client (Arbeit, Test) | Laptop | NixOS |
| Stream-Client (Arbeit, dauerhaft) | Mini-PC (geplant) | NixOS |

---

## Netzwerk-Architektur

```
Internet
   │
Router (192.168.178.1)
   │ WLAN
   │
Laptop/Mini-PC (wlp3s0: 192.168.178.x DHCP)
   │
   │ NAT (Internet-Sharing)
   │
Laptop/Mini-PC (enp2s0: 10.0.0.2/30) ←──── direktes Ethernet-Kabel ────► Gaming-PC (10.0.0.1/30)
```

- Gaming-PC hat **kein** eigenes Router-Kabel — Internet kommt via NAT vom Client-Rechner
- Moonlight streamt direkt über `10.0.0.1` ohne Router dazwischen
- WLAN-Interface des Client-Rechners bleibt unabhängig davon

---

## 1. Windows Gaming-PC — Sunshine

### Installation

1. [github.com/LizardByte/Sunshine/releases](https://github.com/LizardByte/Sunshine/releases) → `sunshine-windows-installer.exe` (**AMD64**, nicht ARM64)
2. Installer als Administrator ausführen
3. Browser öffnen: `https://localhost:47990` (Zertifikatswarnung wegklicken)
4. Benutzername + Passwort setzen (einmalig beim ersten Start)

### Encoder-Überprüfung

Configuration → Video → Encoder muss **nvenc** zeigen (RTX 3080 wird automatisch erkannt).

### Firewall-Regeln (manuell, Installer macht das nicht zuverlässig)

PowerShell als Administrator:

```powershell
New-NetFirewallRule -DisplayName "Sunshine TCP" -Direction Inbound -Protocol TCP -LocalPort 47984,47989,48010 -Action Allow
New-NetFirewallRule -DisplayName "Sunshine UDP" -Direction Inbound -Protocol UDP -LocalPort 47998,47999,48000,48002,48010 -Action Allow
```

**Wichtig:** Ohne diese Regeln kann Moonlight keine Verbindung herstellen. Windows Defender Firewall
blockiert die Ports auch dann wenn die Firewall über die GUI "deaktiviert" wird — die Regeln müssen
explizit gesetzt werden.

### Statische IP (direkte Ethernet-Verbindung)

`Win + R` → `ncpa.cpl` → Rechtsklick auf **Ethernet** → Eigenschaften →
**Internetprotokoll Version 4 (TCP/IPv4)** → Eigenschaften:

| Feld | Wert |
|---|---|
| IP-Adresse | `10.0.0.1` |
| Subnetzmaske | `255.255.255.252` |
| Standardgateway | `10.0.0.2` |
| Bevorzugter DNS-Server | `8.8.8.8` |

Das Gateway `10.0.0.2` ist der Client-Rechner, der Internet via NAT weiterleitet.

### Virtual Display Driver (VDD)

Ohne physischen Monitor gibt Windows keinen Bildschirm aus → Sunshine streamt nichts.
VDD erstellt einen dauerhaften virtuellen Monitor.

1. [github.com/VirtualDrivers/Virtual-Display-Driver/releases](https://github.com/VirtualDrivers/Virtual-Display-Driver/releases) → **`VDD.Control.*.zip`** (nicht die `Driver.Only`-Varianten)
2. ZIP entpacken
3. `installCert.bat` als Administrator ausführen (Zertifikat installieren)
4. Danach den Treiber über die VDD Control-App installieren
5. In Windows-Anzeigeeinstellungen taucht ein neuer virtueller Monitor auf
6. Sunshine kann jetzt streamen auch wenn kein physischer Monitor angeschlossen ist

**Warum `VDD.Control` statt `Driver.Only`:** Die Control-App erlaubt es, den virtuellen Display zu
verwalten (Auflösung setzen, aktivieren/deaktivieren). Der Driver-Only hat keine GUI.

---

## 2. NixOS Client-Rechner — Moonlight + Netzwerk

### Paket

`moonlight-qt` ist in `home/laptop-niri.nix` (bzw. beim Mini-PC im entsprechenden Home-Modul):

```nix
home.packages = with pkgs; [
  # ...
  moonlight-qt
];
```

### Netzwerk-Konfiguration (`hosts/laptop/default.nix`)

```nix
# Statische IP auf dem direkten Ethernet-Interface
networking.interfaces.enp2s0.ipv4.addresses = [{
  address = "10.0.0.2";
  prefixLength = 30;
}];

# Internet-Sharing: WLAN → Ethernet → Gaming-PC
networking.nat = {
  enable = true;
  externalInterface = "wlp3s0";   # WLAN (Internet-Quelle)
  internalInterfaces = [ "enp2s0" ]; # Ethernet zum Gaming-PC
};
```

**Interface-Namen prüfen** (können auf neuem Gerät anders heißen):
```bash
ip link show
```
Ethernet-Interface: typisch `enp*` oder `eth*`, WLAN: typisch `wlp*` oder `wlan*`.

### Mini-PC-spezifisch (umgesetzt 2026-06-09, `hosts/minipc/default.nix`)

Der Mini-PC hat **zwei Ethernet-Ports** und hängt am LAN (kein WLAN-Sharing):
- **`eno1`** = Internet (Router, DHCP `192.168.178.62`) → NAT-Quelle
- **`enp3s0`** = Direktkabel zum Gaming-PC → statische `10.0.0.2/30`
- `moonlight-qt` liegt im Home-Block des `minipc`-Hosts (Binary heißt schlicht **`moonlight`**)

```nix
# NetworkManager darf enp3s0 NICHT verwalten, sonst greift die statische IP nicht!
networking.networkmanager.unmanaged = [ "interface-name:enp3s0" ];

networking.interfaces.enp3s0.ipv4.addresses = [{
  address = "10.0.0.2";
  prefixLength = 30;
}];

networking.nat = {
  enable = true;
  externalInterface = "eno1";        # Internet via Router (nicht WLAN wie beim Laptop)
  internalInterfaces = [ "enp3s0" ]; # Direktkabel zum Gaming-PC
};
```

**Stolperfalle NetworkManager:** Ohne `networking.networkmanager.unmanaged` schnappt sich NM
`enp3s0`, bekommt kein DHCP (Gaming-PC ist kein DHCP-Server) → die statische `10.0.0.2` wird
**nie** gesetzt (`nmcli device status` zeigt enp3s0 dann „nicht verbunden"). Mit `unmanaged`
übernimmt das NixOS-`network-addresses`-Service die statische IP → zeigt „nicht verwaltet".

**Verbindung testen (Ping ist nutzlos):** Windows blockt ICMP per Default → `ping 10.0.0.1`
schlägt **immer** fehl, auch bei funktionierender Verbindung. Stattdessen:
```bash
ping -c1 10.0.0.1; ip neigh show dev enp3s0       # → "REACHABLE" = L2/L3 ok
timeout 3 bash -c 'echo > /dev/tcp/10.0.0.1/47989' && echo "Sunshine erreichbar"
```

### Moonlight-Einstellungen

Nach dem Start: `+` → IP `10.0.0.1` manuell eingeben.

Empfohlene Stream-Einstellungen (Zahnrad-Icon neben dem Host):

| Einstellung | Wert |
|---|---|
| Auflösung | 1920x1080 (oder native Monitor-Auflösung) |
| Framerate | 60 FPS |
| Videobitrate | 50–100 Mbps |

---

## 3. Erst-Kopplung (Pairing)

1. In Moonlight auf den Host klicken → **"Koppeln"**
2. Moonlight zeigt einen **4-stelligen PIN**
3. **Sofort** in Sunshine Web-UI (`https://10.0.0.1:47990`) → PIN-Feld oben eingeben
4. Fertig — Moonlight zeigt die Stream-Apps

**Fehler "Invalid uniqueid (Error 400)":** Sunshine Web-UI → **Devices** → fehlgeschlagenen
Eintrag löschen → Kopplung erneut starten. Passiert wenn der PIN zu langsam eingegeben wird
oder die Reihenfolge falsch war (erst Sunshine, dann Moonlight).

---

## 4. Bekannte Probleme & Lösungen

### Moonlight findet den Host nicht automatisch

Auto-Discovery per mDNS funktioniert nicht zuverlässig. Immer manuell die IP `10.0.0.1`
eingeben (`+`-Button in Moonlight).

### "Kann keine Verbindung herstellen"

- **Ursache:** Sunshine-Firewall-Regeln fehlen
- **Fix:** PowerShell-Befehle aus Abschnitt 1 erneut ausführen

### Bild pixelig/unscharf

- **Ursache:** Bitrate zu niedrig (Standard-Wert in Moonlight ist sehr konservativ)
- **Fix:** Moonlight-Einstellungen → Videobitrate auf 50–100 Mbps erhöhen

### Streaming laggt

- **Ursache A:** Verbindung läuft über WLAN statt direkt
- **Fix A:** Sicherstellen dass Moonlight mit `10.0.0.1` verbunden ist, nicht mit einer anderen IP
- **Ursache B:** Bitrate zu hoch für die Verbindungsqualität
- **Fix B:** Bitrate auf 50 Mbps reduzieren

### Gaming-PC hat kein Internet nach Verbindung

- **Ursache:** NAT auf Client-Rechner läuft nicht, oder Gateway/DNS auf Windows nicht gesetzt
- **Fix:** NixOS `networking.nat` konfiguriert und `rebuild` ausgeführt? Gateway `10.0.0.2` und DNS `8.8.8.8` auf Windows gesetzt?

### Kein Bild wenn Monitor abgesteckt (Black Screen)

- **Ursache:** VDD nicht installiert — Windows hat keinen aktiven Display-Adapter
- **Fix:** VDD installieren (siehe Abschnitt 1)

---

## 5. Physischer Aufbau

```
Ethernet-Kabel direkt:
Gaming-PC (RJ45) ←──────────────────────────► Laptop/Mini-PC (RJ45 oder USB-Ethernet)

WLAN:
Laptop/Mini-PC )))·····(((  Router ─── Internet
```

**Gaming-PC hat kein eigenes Router-Kabel** — Internet kommt ausschließlich über NAT vom
Client-Rechner. Konsequenz: wenn der Client-Rechner aus ist, hat der Gaming-PC kein Internet.

### Geplante dauerhafte Lösung (Mini-PC)

Wenn nur ein Wandanschluss vorhanden ist, bleibt Internet-Sharing die einzige Option ohne
zusätzliche Hardware. Alternative: USB-Ethernet-Adapter am Gaming-PC → Gaming-PC bekommt
einen zweiten Port und bleibt direkt am Router, während das Streaming-Kabel separat läuft.

---

## 6. Moonlight Tastenkombinationen

Alle Shortcuts gelten während eines aktiven Streams:

| Tastenkombination | Funktion |
|---|---|
| `Ctrl+Alt+Shift+Q` | Stream beenden |
| `Ctrl+Alt+Shift+X` | Vollbild ↔ Fenstermodus |
| `Ctrl+Alt+Shift+Z` | Maus/Tastatur-Capture umschalten |
| `Ctrl+Alt+Shift+M` | Mausmodus wechseln (direktes Capture ↔ Remote-Desktop-Zeiger) |
| `Ctrl+Alt+Shift+V` | Text aus lokaler Zwischenablage auf Host einfügen (Remote Strg+V) |
| `Ctrl+Alt+Shift+D` | Streaming-Fenster minimieren |
| `Ctrl+Alt+Shift+S` | Performance-Overlay ein/ausblenden |
| `Ctrl+Alt+Shift+C` | Lokalen Mauszeiger im Remote-Desktop-Modus ein/ausblenden |
| `Ctrl+Alt+Shift+L` | Mauszeiger auf Video-Bereich sperren (benötigt "Maus für Remote-Desktop optimieren") |

**Tipp:** "Erfasse System-Tastenkürzel" in den Moonlight-Einstellungen auf **"Immer"** stellen,
damit Alt+Tab und andere Windows-Shortcuts auch im Fenstermodus an Windows weitergeleitet werden.

---

## 7. Workflow

### Gaming starten

1. Moonlight öffnen
2. Host `10.0.0.1` auswählen (sollte bereits gespeichert sein)
3. Desktop oder gewünschte App starten
4. Vollbild: `Strg+Alt+Umschalt+X` (Moonlight Standard)
5. Moonlight verlassen: selbe Tastenkombination oder `Strg+Alt+Umschalt+Q`

### Sunshine neu koppeln (nach Neuinstallation o.ä.)

1. Sunshine Web-UI `https://10.0.0.1:47990` → Devices → alten Eintrag löschen
2. Kopplung wie in Abschnitt 3 neu durchführen

### Client-Rechner neu einrichten (z.B. neuer Mini-PC)

1. `moonlight-qt` zum entsprechenden Home-Modul hinzufügen
2. In `hosts/<hostname>/default.nix` eintragen:
   - `networking.interfaces.<eth-interface>.ipv4.addresses` mit `10.0.0.2/30`
   - `networking.nat` mit dem korrekten WLAN- und Ethernet-Interface
3. `rebuild` ausführen
4. Moonlight öffnen → `10.0.0.1` → Koppeln

---

## 7. Getesteter Stand (2026-06-06)

- Streaming funktioniert flüssig über direktes Ethernet
- Auflösung 1920x1080 @ 60 FPS, ~80 Mbps
- Audio über USB-Geräte funktioniert
- VDD installiert, Monitor kann abgesteckt werden
- Internet-Sharing vom Laptop (WLAN) zum Gaming-PC über NAT aktiv
- Kopplung gespeichert, nach Neustart direkt verbindbar

### Mini-PC (2026-06-09)

- Mini-PC (`minipc`) als Client eingerichtet und getestet — Stream läuft
- Direktlink `enp3s0` ↔ Gaming-PC, statische `10.0.0.2/30` (NM-unmanaged, reboot-fest)
- Internet-Sharing vom Mini-PC (LAN via `eno1`) zum Gaming-PC über NAT
- Kopplung erfolgreich (Sunshine vom Laptop-Setup unverändert, Client weiterhin `10.0.0.2`)
