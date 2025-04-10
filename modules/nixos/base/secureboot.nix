{ config, deps, lib, pkgs, self', ... }:

let
  cfg = config.x.base.secureboot;
  inherit (deps) lanzaboote;
in
{
  imports = [
    lanzaboote.nixosModules.lanzaboote
  ];

  options.x.base.secureboot = {
    enable = lib.mkOption {
      description = ''
        Enable Secure Boot support.
        
        Putting this option on "setup" enables bind mounts and packages for Lanzaboote but doesn't generate signed boot entries. "setup" is useful for initially generating Secure Boot signing keys.
      '';

      default = true;
      type = with lib.types; either bool (strMatching "setup");
    };
  };

  config = lib.mkIf (cfg.enable != false) {
    # Secure Boot keys do not live in agenix since they are potentially
    # required before the first generation where they would be visible
    # on disk is activated. So they are kind of impure and have to be
    # handled manually unlike other secrets.
    x.base.filesystems.persistentDirectories = [
      "/etc/secureboot"
    ];

    # Use the systemd-boot EFI boot loader.
    boot.loader.systemd-boot.enable = self'.lib.mkIfElse (cfg.enable == "setup")
      true
      (lib.mkForce false); # Required this way for Lanzaboote
    boot.loader.efi.canTouchEfiVariables = true;

    boot.lanzaboote = {
      enable = cfg.enable == true;
      pkiBundle = "/etc/secureboot";
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
