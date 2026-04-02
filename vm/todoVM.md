
dann lass uns jetzt eine kleine todo liste erstellen als datei.

2 Check ob sound automatisch von kopfhörer kommen.
6 copy paste text von linux zu vm und anderrum
10 Einen besseren weg bekommen um die vm zu steuern: auf einmal vm und looking glass starten und beenden.
- Nicht direkt tastutur und maus switchen, das mache ich manuell wenn er gestartet ist
- Immer auf dem main bildschirm starten und im vollbild
- Start Stop hub.
- von windows aus vm stop aufrufen
- Vm pause hinzufügen
- mit vm den vm manager öffnen
11 die anderen bildschirme deaktivieren
12 Andere Festplatten sichtbar machen, da dort spiele installiert werden.
- Bei vm stop alle festplatten korrekt bei linux mounten
14 Ich muss beim start immer mein zweiten monitor von dp zu hdmi wechseln, wie genau automatisiere ich das?
15 Nix config aufräumen und aufteilen.



Info:
upscaling ist der grund warum looking glass pixelig ist
looking-glass-client win:size=2560x1440 win:dontUpscale=on spice:enable=no
wenn wir lg so starten, dann ist es nicht mehr pixelig, jedoch sind wir auf 1920x1080, weil der bildschirm mit dem die gpu verbunden ist diese auflösung hat. 


spice ist etwas verwirrend: wir haben unser eigenes "spice" gebaut, ich kann jetzt mit spice den bildschirm kontrollieren aber auch wenn ich scrolllock tippe, wenn spice keine latenz hat kann man überlegen nur das zu nutzen. Wobei spice nicht richtig win und tab abfängt also lieber nicht nutzen.  
