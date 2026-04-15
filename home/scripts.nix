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

    (pkgs.writeShellScriptBin "git-push-all" ''
      for dir in ~/gitprojs/*/; do
        if git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
          name=$(basename "$dir")
          unpushed=$(git -C "$dir" log @{u}.. --oneline 2>/dev/null)
          if [ -n "$unpushed" ]; then
            echo "Pushe $name..."
            git -C "$dir" push && echo "  ✓ $name gepusht" || echo "  ✗ $name fehlgeschlagen"
          fi
        fi
      done
    '')

    (pkgs.writeShellScriptBin "rebuild" ''
      MESSAGE="''${1:-update}"
      DATE=$(date '+%Y-%m-%d %H:%M')
      TIME=$(date '+%H:%M')
      LABEL=$(echo "$MESSAGE--$TIME" | tr ' ' '-' | sed 's/[^a-zA-Z0-9:_.-]/-/g')
      echo "$LABEL" > /home/leonardn/nixos-config/label.txt

      echo ""
      echo "┌─── git ────────────────────────────────────────"

      if ! mountpoint -q /boot; then
        echo "│ ⚠ /boot nicht gemountet, mounte..."
        sudo mount /boot
      fi

      cd /home/leonardn/nixos-config
      git pull --rebase origin main
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
