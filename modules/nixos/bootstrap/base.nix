{ config, lib, name, ... }:

let
  cfg = config.x.bootstrap;
in
{
  options.x.bootstrap.enable = lib.mkEnableOption "bootstrapping modules";

  config = lib.mkIf cfg.enable {
    x.base = {
      restic.enableAutomaticBackups = false;
      secureboot.enable = false;
      sshd.enable = true;

      tailscale.bootstrapping = true;
    };

    environment.etc.machine-id.enable = false;
    services.tailscale.authKeyFile = "${config.x.base.filesystems.persistDirectory}/tailscale-auth-key";

    systemd.services.copy-machine-id = {
      script = ''
        set -eu
        mkdir -p /persist/etc
        cp -f /etc/machine-id /persist/etc/machine-id
      '';

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };

      wantedBy = [ "multi-user.target" ];
    };

    x.global.netsrv.hosts.${name} = lib.mkDefault "127.0.0.1";
  };
}
