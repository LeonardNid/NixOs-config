# Wake-on-LAN – Untersuchung & Ergebnis (minipc + leoserver)

Stand: 2026-06-10

Ziel war, die Rechner **vom Handy (WoL-App) aufzuwecken**. Betroffen sind zwei Maschinen:

| Host | OS | NIC (`eno1`) MAC | Rolle |
|---|---|---|---|
| **minipc** (GMKtec Nucbox M6) | NixOS | `84:47:09:86:FF:C2` | Niri-Desktop / Moonlight-Client |
| **leoserver** | Ubuntu 24.04 LTS | `b8:ca:3a:97:8d:59` | Docker-Server |

**Kurzfassung des Ergebnisses:**
- Aus **Suspend (S3)** wachen **beide** Maschinen zuverlässig per WoL auf. ✅
- Aus **Poweroff (S5)** wacht **keine** der beiden auf — aber aus **zwei verschiedenen Gründen**:
  - **minipc:** Hardware-Limit. Das Board legt im S5 keinen Standby-Strom auf die NIC (LED an der LAN-Buchse ist im Aus dunkel). Kein ErP/Deep-Sleep-Toggle im BIOS vorhanden → **per Software/BIOS nicht behebbar**. → **Suspend nutzen.**
  - **leoserver:** Regression nach **Stromausfall**. Das CMOS/BIOS wurde dabei zurückgesetzt und damit die S5-Standby-Versorgung der NIC (PME / „Power On by PCI-E"). → **im BIOS wieder aktivieren** (siehe unten).

---

## Diagnose-Weg (was wir geprüft und ausgeschlossen haben)

### 1. Kommen die Magic Packets überhaupt an? — JA
Mit `tcpdump` auf dem MiniPC (Filter `udp[8:4] = 0xffffffff`) bei *laufender* Kiste mitgeschnitten,
während vom Handy mehrfach „wake" gedrückt wurde. Ergebnis: 10 saubere Magic Packets vom Handy
(`192.168.178.59`), gesendet an **beide** Adressen:
- Unicast an den MiniPC (`192.168.178.62.9`, Ethernet-Ziel = MiniPC-MAC)
- Subnetz-Broadcast (`192.168.178.255.9`, Ethernet-Ziel = `ff:ff:ff:ff:ff:ff`)

Payload jeweils korrekt: 6× `0xFF` (Sync) + 16× Ziel-MAC. → **Netzwerk, Router, App, MAC, Broadcast
sind alle in Ordnung.** Das Problem liegt rein auf der **Aufweck-Seite**.

### 2. Ist die NIC im Betrieb scharf? — JA, bei beiden
```
ethtool eno1 →  Supports Wake-on: pumbg   Wake-on: g
```
`g` = Magic Packet. Beide NICs sind im laufenden Betrieb korrekt armiert.

### 3. Wecken über Kabel statt Handy — schließt WLAN/Router aus
Vom MiniPC (eingeschaltet) aus an leoserver (aus) gesendet:
```bash
nix run nixpkgs#wakeonlan -- -i 192.168.178.255 b8:ca:3a:97:8d:59
```
Default-Route des MiniPC geht über `eno1` ins Heim-LAN → Paket war korrekt im LAN. leoserver blieb
trotzdem aus. → bestätigt: kein Handy-/Router-/WLAN-Problem, sondern die Aufweck-Seite der Rechner.

### 4. Der entscheidende Test: LED an der LAN-Buchse
- **Suspend (S3):** LED leuchtet → NIC bestromt → WoL **funktioniert** (beide Hosts).
- **Poweroff (S5):** LED **aus** → NIC stromlos → WoL **unmöglich** (beide Hosts).

### 5. Shutdown-Re-Arm-Skript — hat NICHT geholfen
Versuch auf leoserver: `/usr/lib/systemd/system-shutdown/wol-rearm` mit `ethtool -s eno1 wol g`.
Bringt nichts, weil der Treiber den PHY beim Herunterfahren schon vorher stromlos fährt; danach
kann `ethtool` nichts mehr halten. Die LED bleibt aus. → bestätigt, dass es **keine fehlende
Armierung** ist, sondern **fehlender Standby-Strom**.

### 6. Beide LAN-Ports des MiniPC getestet — beide tot im S5
Der MiniPC hat **zwei** RTL8125-Ports (separate PCI-Geräte `01:00.0` und `03:00.0`, beide Treiber
`r8169`, beide `Supports Wake-on: pumbg`):
- `eno1` = `84:47:09:86:FF:C2` (Heim-LAN)
- `enp3s0` = `84:47:09:86:FF:C1` (Direktlink, statisch `10.0.0.2/30`)

Hypothese „vielleicht bekommt nur ein Port Standby-Strom" geprüft: `enp3s0` mit `ethtool -s enp3s0
wol g` armiert, Heim-Kabel umgesteckt, `poweroff`, Magic Packet an `…FF:C1`. → **Ebenfalls keine
LED, kein Wakeup.** Beide Ports sind gleich verdrahtet → der Standby-Strom fehlt board-weit, nicht
nur an einem Port.

## Warum hat das BIOS dann überhaupt eine „Wake on LAN"-Option?
Kein Widerspruch:
1. **Die Option ist nicht nutzlos** — genau sie ermöglicht den **Suspend-WoL (S3)**, der ja
   funktioniert. Ohne sie ginge auch das nicht.
2. **S5-WoL braucht zwei Dinge, das BIOS steuert nur eines:** (a) der Chipsatz muss das Wake-Event
   (PME#) erlauben → das schaltet die Option; (b) die NIC muss im S5 Standby-Strom (+5VSB)
   bekommen → reine **Platinen-Verdrahtung**, dafür gibt's keinen Schalter. Board liefert (a),
   nicht (b).
3. **Stock-BIOS-Vorlage:** GMKtec nutzt eine generische AMI-Aptio-Vorlage, die Standard-Optionen
   („Wake on LAN", „PME") über viele Modelle hinweg zeigt — unabhängig davon, ob das konkrete Board
   die +5VSB-Leitung zur NIC hat. Oft gilt die Option nur für S3/S4, nicht für den vollen Soft-Off.

## Randnotiz: RTC-Wakeup geht, WoL nicht — warum?
**RTC-Wakeup** (Aufwachen zu fester Uhrzeit, `rtcwake`) läuft auf der **CMOS-Knopfzelle** — die ist
immer bestromt, sogar ohne Stromnetz, und braucht **keinen** Netzteil-Standby. Deshalb funktioniert
RTC-Wake aus S5, obwohl WoL es nicht tut: WoL braucht die **aktiv lauschende, bestromte NIC**, RTC
nur den winzigen batteriegepufferten Uhren-Chip. RTC ist allerdings nur ein **Timer** (feste
Uhrzeit), kein on-demand-Wecken wie WoL.

---

## Warum „zwei Maschinen gleichzeitig, ich hab nichts geändert"?
Reiner Zufall, dass beide gleichzeitig auffielen — zwei unabhängige Ursachen:
- **leoserver** wachte früher aus S5 auf → durch den **Stromausfall** ging die BIOS-Einstellung verloren.
- **minipc** ging aus S5 **noch nie** (frische Einrichtung) → Hardware-Eigenschaft des Boards,
  hat mit dem Stromausfall nichts zu tun.

---

## Lösungen

### leoserver — BIOS wieder einstellen (nach Stromausfall)
Ins BIOS booten und aktivieren:
- **„PME Event Wake Up" / „Resume by PCI-E Device" / „Power On By PCIE/PCI" / „Wake on LAN"** → **Enable**
- falls vorhanden: **„ErP" / „EuP" / „Deep Sleep"** → **Disable**
- Bonus für die Zukunft: **„Restore on AC Power Loss"** → **„Power On"** / **„Last State"**
  → fährt nach dem nächsten Stromausfall von selbst hoch (besser als WoL für diesen Fall).

Schneller Weg ins Setup auf systemd/UEFI-Systemen (kein Del-Spammen):
```bash
systemctl reboot --firmware-setup
```

### minipc — Suspend statt Poweroff
S5-WoL ist hardwareseitig nicht möglich. Lösung: zum Aufwecken **Suspend (S3)** nutzen.
```bash
systemctl suspend
```
Aufwecken vom Handy bzw. per `wakeonlan 84:47:09:86:FF:C2`. Stromverbrauch im S3 nur wenige Watt,
Aufwachen in Sekunden (RAM-Inhalt bleibt erhalten, kein kompletter Boot).

`poweroff` bleibt natürlich weiter verfügbar, wenn die Kiste mal wirklich ganz aus sein soll.

---

## Hintergrund: S3 (Suspend) vs. S5 (Poweroff)

| | Poweroff (S5) | Suspend (S3) |
|---|---|---|
| RAM-Inhalt | weg | bleibt erhalten |
| NIC bestromt? | nur wenn Board +5VSB durchlegt (minipc: **nein**) | **ja** |
| WoL | bei unserer Hardware nicht | **funktioniert** |
| Hochfahren | voller Boot | sofort (Sekunden) |
| Stromverbrauch | ~0 W | wenige W |

(S4 / Hibernate hilft nicht: schreibt RAM auf Platte und geht dann in echtes Aus wie S5 → gleiches
Standby-Problem für WoL.)

---

## Verbleibende Config (minipc, `hosts/minipc/default.nix`)
Die WoL-Armierung im OS bleibt sinnvoll (für Suspend-WoL nötig):
```nix
networking.interfaces.eno1.wakeOnLan.enable = true;                       # erzeugt 40-eno1.link, WakeOnLan=magic
networking.networkmanager.settings.connection."ethernet.wake-on-lan" = 64; # NM setzt das Flag sonst auf 'd' zurück (64 = MAGIC)
```
Verifizieren: `ethtool eno1 | grep -i wake` → `Wake-on: g`.
