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
    initExtra = ''
      eval "$(zoxide init zsh)"
    '';
  };

  programs.starship.enable = true;
}
