{ config, lib, ... }:

let
  cfg = config.x.services.remotebuild;
in
{
  options.x.services.remotebuild.enable = lib.mkEnableOption "a trusted user for distributed builds";

  config = lib.mkIf cfg.enable {
    users.users.remotebuild = {
      isNormalUser = true;
      createHome = false;
      group = "remotebuild";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAREDACTED root@mikubook"
      ];
    };

    users.groups.remotebuild = { };

    nix.settings.trusted-users = [ "remotebuild" ];
  };
}
