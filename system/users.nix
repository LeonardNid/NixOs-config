{ pkgs, ... }:

{
  # Passwordless sudo für leonardn
  security.sudo.extraRules = [{
    users = [ "leonardn" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  users.users.leonardn = {
    isNormalUser = true;
    description = "Leonard Niedens";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "plugdev" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  programs.zsh.enable = true;
  services.tailscale.enable = true;

  environment.sessionVariables = {
    DEFAULT_BROWSER = "vivaldi-stable";
    BROWSER = "vivaldi-stable";
  };

  environment.shellAliases = {
    gemini = "npx @google/gemini-cli";
  };
}
