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

    (pkgs.writeShellScriptBin "power-menu" ''
      chosen=$(printf "󰌾  Sperren\n󰒲  Schlafen\n󰏤  Hibernate\n󰑙  Neustart\n󰐥  Ausschalten" \
        | fuzzel --dmenu --prompt="⏻   " --width=22 --lines=5)
      case "$chosen" in
        *Sperren*)     swaylock ;;
        *Schlafen*)    systemctl suspend ;;
        *Hibernate*)   systemctl hibernate ;;
        *Neustart*)    systemctl reboot ;;
        *Ausschalten*) systemctl poweroff ;;
      esac
    '')

    (pkgs.writeShellScriptBin "waybar-mic-status" ''
      if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
        echo '{"text":"󰍭 Stumm","class":"muted","tooltip":"Mikrofon stumm"}'
      else
        echo '{"text":"󰍬","class":"active","tooltip":"Mikrofon aktiv"}'
      fi
    '')

    (pkgs.writeShellScriptBin "mic-toggle" ''
      # Physisches Mikrofon (TONOR TD510) + Easy Effects Source synchron muten/unmuten.
      # wpctl akzeptiert nur numerische IDs, daher ID dynamisch aus "wpctl status" lesen.
      TONOR_ID=$(wpctl status | grep -A 30 'Sources:' | grep 'TONOR TD510' | grep -oP '\b\d+(?=\.)')
      if [ -z "$TONOR_ID" ]; then
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      elif wpctl get-volume "$TONOR_ID" | grep -q MUTED; then
        wpctl set-mute "$TONOR_ID" 0
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
      else
        wpctl set-mute "$TONOR_ID" 1
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
      fi
      pkill -SIGRTMIN+1 waybar 2>/dev/null || true
    '')

    (pkgs.writeShellScriptBin "nc-pick" ''
      NC_DIR="$HOME/Nextcloud"
      STAGING="$HOME/.cache/nc-pick"

      rm -rf "$STAGING"
      mkdir -p "$STAGING"

      mapfile -t selected < <(
        fd . "$NC_DIR" -t f --follow |
        fzf --multi \
            --prompt="  Nextcloud > " \
            --delimiter "/" \
            --with-nth "4.." \
            --preview='bat --color=always --style=numbers -- {}' \
            --preview-window=right:50%:wrap \
            --bind=tab:toggle+down \
            --bind=shift-tab:toggle+up
      )

      [ ''${#selected[@]} -eq 0 ] && exit 0

      for f in "''${selected[@]}"; do
        name=$(basename "$f")
        target="$STAGING/$name"
        if [ -L "$target" ] || [ -e "$target" ]; then
          i=1
          base="''${name%.*}"
          ext="''${name##*.}"
          [ "$base" = "$ext" ] && ext=""
          while [ -e "$STAGING/''${base}_''${i}''${ext:+.}''${ext}" ]; do i=$((i+1)); done
          target="$STAGING/''${base}_''${i}''${ext:+.}''${ext}"
        fi
        ln -sf "$f" "$target"
      done

      dolphin "$STAGING"
    '')

    (pkgs.writeShellScriptBin "rebuild" ''
      RED='\033[1;31m'
      GREEN='\033[1;32m'
      YELLOW='\033[1;33m'
      RESET='\033[0m'

      # Git immer als echter User ausführen, auch wenn rebuild mit sudo aufgerufen wird
      REAL_USER="''${SUDO_USER:-$USER}"
      REPO="/home/leonardn/nixos-config"
      if [ -n "$SUDO_USER" ]; then
        git() { sudo -u "$REAL_USER" git "$@"; }
      fi

      UPDATE=0
      if [ "''${1:-}" = "-u" ]; then
        UPDATE=1
        shift
      fi

      MESSAGE="''${1:-update}"
      DATE=$(date '+%Y-%m-%d %H:%M')
      TIME=$(date '+%H:%M')
      LABEL=$(echo "$MESSAGE--$TIME" | tr ' ' '-' | LC_ALL=C sed 's/[^a-zA-Z0-9:_.-]/-/g')

      if [ $UPDATE -eq 1 ]; then
        echo ""
        echo "┌─── flake update ───────────────────────────────"
        if sudo -u "$REAL_USER" nix flake update --flake "$REPO"; then
          echo -e "│ ''${GREEN}✓ flake.lock aktualisiert''${RESET}"
        else
          echo -e "│ ''${RED}✗ flake update fehlgeschlagen!''${RESET}"
          exit 1
        fi
        echo "└────────────────────────────────────────────────"
      fi

      echo ""
      echo "┌─── git ────────────────────────────────────────"

      if ! mountpoint -q /boot; then
        echo -e "│ ''${YELLOW}⚠ /boot nicht gemountet, mounte...''${RESET}"
        sudo mount /boot
      fi

      cd "$REPO"
      STASHED=0
      if ! git diff --quiet || ! git diff --cached --quiet; then
        git stash
        STASHED=1
      fi

      if ! git pull --rebase origin main; then
        [ $STASHED -eq 1 ] && git stash pop
        echo "│"
        echo -e "│ ''${RED}✗ Rebase-Konflikt in:''${RESET}"
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
          a) git rebase --abort; echo -e "│ ''${YELLOW}Abgebrochen.''${RESET}"; exit 1;;
          s) git rebase --skip || exit 1;;
          m) echo "│ Löse den Konflikt, dann: git add . && git rebase --continue"; exit 1;;
          *) echo -e "│ ''${RED}Unbekannte Eingabe, breche ab.''${RESET}"; git rebase --abort; exit 1;;
        esac
      fi

      [ $STASHED -eq 1 ] && git stash pop

      echo "$LABEL" > "$REPO/label.txt"
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

      if sudo nixos-rebuild switch --flake "$REPO#$(hostname)"; then
        echo ""
        echo -e "''${GREEN}┌────────────────────────────────────────────────┐''${RESET}"
        echo -e "''${GREEN}│  ✓ Build erfolgreich                           │''${RESET}"
        echo -e "''${GREEN}└────────────────────────────────────────────────┘''${RESET}"
      else
        echo ""
        echo -e "''${RED}┌────────────────────────────────────────────────┐''${RESET}"
        echo -e "''${RED}│  ✗ Build fehlgeschlagen!                       │''${RESET}"
        echo -e "''${RED}└────────────────────────────────────────────────┘''${RESET}"
        echo ""
        exit 1
      fi

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
      if git push; then
        echo -e "│ ''${GREEN}✓ gepusht''${RESET}"
      else
        echo -e "│ ''${RED}✗ Push fehlgeschlagen!''${RESET}"
      fi
      echo "└────────────────────────────────────────────────"
      echo ""
    '')
  ];
}
