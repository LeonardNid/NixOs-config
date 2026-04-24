{ ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      nf = ''file=$(fd . ~/Nextcloud | fzf) && xdg-open "$file"'';
      e = "eza";
      ea = "eza -A";
      c = "clear";
    };
    initContent = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.starship.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
