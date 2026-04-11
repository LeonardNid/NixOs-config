git log --oneline

Das zeigt alle Commits. Mit den Pfeiltasten scrollen, q zum Beenden.

Wenn du einen Commit genauer ansehen willst:

git show 9b61d96          # Was wurde in diesem Commit geändert?
git diff 9b61d96 HEAD     # Unterschied zwischen damals und jetzt

Wenn du weißt wohin du zurück willst, z.B. zu 9b61d96:

# Schritt 1: Lokal zurücksetzen
git reset --hard 9b61d96

# Schritt 2: GitHub überschreiben
git push --force

# Schritt 3: NixOS neu bauen
rebuild "revert 9b61d96"
