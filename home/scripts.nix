{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "rebuild" ''
      MESSAGE="''${1:-update}"
      DATE=$(date '+%Y-%m-%d %H:%M')
      TIME=$(date '+%H:%M')
      # Label für Boot-Menü: Nachricht--Uhrzeit (nur erlaubte Zeichen)
      LABEL=$(echo "$MESSAGE--$TIME" | tr ' ' '-' | sed 's/[^a-zA-Z0-9:_.-]/-/g')
      echo "$LABEL" > /home/leonardn/nixos-config/label.txt
      cd /home/leonardn/nixos-config
      git add .
      if ! git diff --cached --quiet; then
        git commit -m "$MESSAGE ($DATE)"
      fi
      sudo nixos-rebuild switch --flake /home/leonardn/nixos-config#leonardn
      git push
    '')
  ];
}
