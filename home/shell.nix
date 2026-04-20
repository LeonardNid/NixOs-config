{ ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      nf = "fd . ~/Nextcloud | fzf | xargs -r xdg-open";
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
