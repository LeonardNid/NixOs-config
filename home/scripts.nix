{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "git-overview" ''
      for dir in ~/gitprojs/*/; do
        if git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
          name=$(basename "$dir")
          changes=$(git -C "$dir" status -s 2>/dev/null)
          unpushed=$(git -C "$dir" log @{u}.. --oneline 2>/dev/null)

          if [ -n "$changes" ] || [ -n "$unpushed" ]; then
            echo "── $name ──────────────────────"
            [ -n "$unpushed" ] && echo "  ⇡ unpushed: $(echo "$unpushed" | wc -l) commit(s)"
            [ -n "$changes"  ] && echo "$changes" | sed 's/^/  /'
          else
            echo "── $name ── ok"
          fi
        fi
      done
    '')

    (pkgs.writeShellScriptBin "git-pull-all" ''
      for dir in ~/gitprojs/*/; do
        if git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
          name=$(basename "$dir")
          git -C "$dir" fetch --quiet 2>/dev/null
          unpulled=$(git -C "$dir" log ..@{u} --oneline 2>/dev/null)
          if [ -n "$unpulled" ]; then
            echo "Pulle $name..."
            git -C "$dir" pull --rebase && echo "  ✓ $name aktualisiert" || echo "  ✗ $name fehlgeschlagen"
          fi
        fi
      done
    '')

    (pkgs.writeShellScriptBin "git-push-all" ''
      for dir in ~/gitprojs/*/; do
        if git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
          name=$(basename "$dir")
          dirty=$(git -C "$dir" status --porcelain 2>/dev/null | grep -v '^??')
          if [ -n "$dirty" ]; then
            echo "Committe $name..."
            git -C "$dir" add -u
            git -C "$dir" commit -m "update" && echo "  ✓ $name committet" || echo "  ✗ $name commit fehlgeschlagen"
          fi
          unpushed=$(git -C "$dir" log @{u}.. --oneline 2>/dev/null)
          if [ -n "$unpushed" ]; then
            echo "Pushe $name..."
            git -C "$dir" push && echo "  ✓ $name gepusht" || echo "  ✗ $name fehlgeschlagen"
          fi
        fi
      done
    '')

    (pkgs.writeShellScriptBin "mic-toggle" ''
      # Physisches Mikrofon (TONOR TD510) + Easy Effects Source synchron muten/unmuten.
      # Nötig weil @DEFAULT_AUDIO_SOURCE@ nur die virtuelle Easy Effects Source trifft,
      # aber das physische Gerät weiter aufnimmt.
      TONOR="alsa_input.usb-TONOR_TONOR_TD510_Dynamic_Mic_2024-04-01A-00.iec958-stereo"
      if wpctl get-volume "$TONOR" 2>/dev/null | grep -q MUTED; then
        wpctl set-mute "$TONOR" 0
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
      else
        wpctl set-mute "$TONOR" 1
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
      fi
    '')

    (pkgs.writeShellScriptBin "rebuild" ''
      MESSAGE="''${1:-update}"
      DATE=$(date '+%Y-%m-%d %H:%M')
      TIME=$(date '+%H:%M')
      LABEL=$(echo "$MESSAGE--$TIME" | tr ' ' '-' | LC_ALL=C sed 's/[^a-zA-Z0-9:_.-]/-/g')

      echo ""
      echo "┌─── git ────────────────────────────────────────"

      if ! mountpoint -q /boot; then
        echo "│ ⚠ /boot nicht gemountet, mounte..."
        sudo mount /boot
      fi

      cd /home/leonardn/nixos-config
      STASHED=0
      if ! git diff --quiet || ! git diff --cached --quiet; then
        git stash
        STASHED=1
      fi

      if ! git pull --rebase origin main; then
        [ $STASHED -eq 1 ] && git stash pop
        echo "│"
        echo "│ ✗ Rebase-Konflikt in:"
        git diff --name-only --diff-filter=U | sed 's/^/│   /'
        echo "│"
        git diff --diff-filter=U | sed 's/^/│ /'
        echo "│"
        echo "│ Was möchtest du tun?"
        echo "│   [a] Rebase abbrechen (ursprünglicher Zustand)"
        echo "│   [s] Meinen lokalen Commit überspringen"
        echo "│   [m] Manuell lösen (rebuild danach erneut starten)"
        printf "│ > "
        read -r choice
        case $choice in
          a) git rebase --abort; echo "│ Abgebrochen."; exit 1;;
          s) git rebase --skip || exit 1;;
          m) echo "│ Löse den Konflikt, dann: git add . && git rebase --continue"; exit 1;;
          *) echo "│ Unbekannte Eingabe, breche ab."; git rebase --abort; exit 1;;
        esac
      fi

      [ $STASHED -eq 1 ] && git stash pop

      echo "$LABEL" > /home/leonardn/nixos-config/label.txt
      git add .
      if ! git diff --cached --quiet; then
        git commit -m "$MESSAGE ($DATE)"
      else
        echo "│ nichts zu committen"
      fi

      echo "└────────────────────────────────────────────────"
      echo ""
      echo "┌─── nixos-rebuild ──────────────────────────────"
      echo ""

      sudo nixos-rebuild switch --flake /home/leonardn/nixos-config#$(hostname)

      echo ""
      echo "└────────────────────────────────────────────────"

      if [ "$(hostname)" = "laptop" ] && [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        echo ""
        echo "┌─── hyprland ───────────────────────────────────"
        hyprctl reload
        systemctl --user restart hyprpaper
        echo "└────────────────────────────────────────────────"
      fi

      echo ""
      echo "┌─── git push ───────────────────────────────────"
      git push
      echo "└────────────────────────────────────────────────"
      echo ""
    '')
  ];
}
