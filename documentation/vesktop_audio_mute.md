# Vesktop (Discord) Audio Mute Toggle unter Wayland / PipeWire

## Problemstellung
Es bestand der Wunsch, mit einem globalen Hotkey (z. B. `F24`) nicht mehr den gesamten PC stummzuschalten, sondern gezielt nur den Sound der App "Vesktop" (ein alternativer Discord-Client für Linux) zusammen mit dem eigenen Mikrofon.

Dabei ergaben sich zwei wesentliche Hürden im Zusammenspiel mit Electron-Apps und PipeWire (`wpctl`):

1. **Falscher Prozessname in PipeWire:**
   Electron-basierte Anwendungen wie Vesktop (und Discord) tauchen in PipeWire/WirePlumber nicht unter ihrem eigenen Namen (z. B. "Vesktop") auf, sondern als generischer `Chromium` bzw. `Chromium input` Stream.
   Außerdem wird das Audio nicht im Hauptprozess der Anwendung verarbeitet, sondern in einem separaten Chromium-Utility-Prozess.

2. **Bug in `wpctl toggle` für Prozesse:**
   PipeWire bietet mit `wpctl set-mute -p <PID> toggle` theoretisch die Möglichkeit, alle Audio-Nodes einer bestimmten Prozess-ID stummzuschalten oder wieder zu aktivieren.
   Es hat sich jedoch herausgestellt, dass der `toggle`-Befehl bei der Verwendung in Kombination mit dem `-p` Flag fehlerhaft ist: Die Streams werden zwar auf `MUTED` gesetzt, lassen sich danach über den gleichen Befehl aber **nicht wieder entmuten** (sie bleiben dauerhaft stummgeschaltet).

## Die Lösung

Um diese Probleme zu umgehen, wurde ein Skript namens `vesktop-toggle` in der Nix-Konfiguration (in `home/scripts.nix`) erstellt.

### Funktionsweise des Skripts:

1. **Den korrekten Audio-Prozess finden:**
   Statt nach "Vesktop" zu suchen, sucht das Skript über `pgrep` nach dem spezifischen Chromium-Audio-Utility-Prozess:
   `utility-sub-type=audio.mojom.AudioService`
   Über eine weitere Prüfung mit `ps` wird dann verifiziert, dass dieser Prozess tatsächlich zur Vesktop-Instanz gehört.

2. **Individuelle Node-IDs auslesen:**
   Über `pw-dump` und das JSON-Werkzeug `jq` werden exakt die PipeWire-Nodes (`PipeWire:Interface:Node`) ermittelt, deren `application.process.id` mit der gefundenen PID des Audio-Prozesses übereinstimmt.

3. **Status prüfen und manuell toggeln:**
   Um den `toggle`-Bug von `wpctl -p` zu umgehen, prüft das Skript den aktuellen Status (Lautstärke und Mute-Status) des **ersten** gefundenen Nodes mit `wpctl get-volume`.
   Abhängig davon, ob dort `MUTED` steht oder nicht, wird der Zielstatus explizit auf `0` (Unmute) oder `1` (Mute) gesetzt. 
   Anschließend iteriert das Skript über alle gefundenen Node-IDs und wendet diesen fixen Zielstatus an (`wpctl set-mute <ID> <TARGET>`).

### Das Skript (`home/scripts.nix`)

```bash
(pkgs.writeShellScriptBin "vesktop-toggle" ''
  # Finde den AudioService-Prozess von Vesktop.
  AUDIO_PIDS=$(pgrep -f "utility-sub-type=audio.mojom.AudioService")
  
  for pid in $AUDIO_PIDS; do
    if ps -p "$pid" -o args= | grep -q -i "vesktop"; then
      # Finde alle PipeWire-Nodes für diesen Prozess
      NODES=$(pw-dump | ${pkgs.jq}/bin/jq -r --argjson pid "$pid" '.[] | select(.type == "PipeWire:Interface:Node") | select(.info.props."application.process.id" == $pid) | .id')
      
      if [ -n "$NODES" ]; then
        # Zustand des ersten Nodes bestimmen
        FIRST_NODE=$(echo "$NODES" | head -n 1)
        if wpctl get-volume "$FIRST_NODE" | grep -q "MUTED"; then
          TARGET=0
        else
          TARGET=1
        fi
        
        # Alle Nodes auf den Zielzustand setzen
        for id in $NODES; do
          wpctl set-mute "$id" "$TARGET"
        done
      fi
    fi
  done
'')
```

### Einbindung im Window Manager (Niri)

In der Niri-Konfiguration (`home/desktop-niri.nix`) wurde der Hotkey dann wie folgt angepasst, um sowohl das Mikrofon als auch Vesktop stummzuschalten:

```nix
F24 allow-when-locked=true { spawn "sh" "-c" "vesktop-toggle; mic-toggle"; }
```
