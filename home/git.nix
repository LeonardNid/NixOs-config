{ ... }:

{
  programs.git = {
    enable = true;
    userName = "Leonard Niedens";
    userEmail = "niedens03@gmail.com";
    extraConfig.init.defaultBranch = "main";
  };
}
