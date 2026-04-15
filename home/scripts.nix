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
      # Label für Boot-Menü: Nachricht--Uhrzeit (nur erlaubte Zeichen)
      LABEL=$(echo "$MESSAGE--$TIME" | tr ' ' '-' | sed 's/[^a-zA-Z0-9:_.-]/-/g')
      echo "$LABEL" > /home/leonardn/nixos-config/label.txt
      # /boot mounten falls nötig (verhindert Bootloader-Fehler beim Rebuild)
      if ! mountpoint -q /boot; then
        echo "⚠ /boot nicht gemountet, mounte..."
        sudo mount /boot
      fi
      cd /home/leonardn/nixos-config
      git add .
      if ! git diff --cached --quiet; then
        git commit -m "$MESSAGE ($DATE)"
      fi
      sudo nixos-rebuild switch --flake /home/leonardn/nixos-config#$(hostname)
      # Hyprland-Config neu laden, falls auf dem Laptop unter Hyprland
      if [ "$(hostname)" = "laptop" ] && [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        hyprctl reload
      fi
      git push
    '')
  ];
}
