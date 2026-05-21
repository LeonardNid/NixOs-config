# Nautilus Papierkorb Fix (Laptop)

Die Systemkonfiguration (`services.gvfs.enable = true` in `system/niri.nix`) ist bereits korrekt
und gilt für beide Hosts.

## Einmalig auf dem Laptop ausführen

Falls der Papierkorb in Nautilus den Fehler "Orte vom Typ »trash« werden nicht unterstützt" zeigt:

```bash
# Kaputtes Override-File entfernen (Überrest eines fehlgeschlagenen Konfigurationsversuchs)
rm ~/.config/systemd/user/gvfs-daemon.service

# Dienst neu laden und starten
systemctl --user daemon-reload
systemctl --user start gvfs-daemon.service
```

Danach funktioniert der Papierkorb ohne Neustart. Der Dienst startet bei künftigen
Sitzungen automatisch per D-Bus-Aktivierung.
