{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Leonard Niedens";
      user.email = "niedens03@gmail.com";
      init.defaultBranch = "main";
    };
  };
}
