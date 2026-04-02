{ ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
    };
    initContent = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.starship.enable = true;
}
