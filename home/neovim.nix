{ ... }:

{
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraConfig = ''
      set clipboard=unnamedplus
    '';
  };
}
