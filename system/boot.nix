{ self, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
  system.configurationRevision = self.rev or "dirty";
  system.nixos.label = builtins.replaceStrings ["\n"] [""] (builtins.readFile (self + "/label.txt"));
}
