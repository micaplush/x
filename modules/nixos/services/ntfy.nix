{ config, globalConfig, lib, ... }:

let
  cfg = config.x.services.ntfy;

  localPort = config.x.base.localport.ports.ntfy;
in
{
  options.x.services.ntfy.enable = lib.mkEnableOption "ntfy.sh";

  config = lib.mkIf cfg.enable {
    x.base.localport.decls.ntfy = { };

    x.server.caddy.services.ntfy.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString localPort}
    '';

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${globalConfig.netsrv.services.ntfy.fqdn}";
        listen-http = "127.0.0.1:${builtins.toString localPort}";
      };
    };

    systemd.services.ntfy-sh = {
      requires = [ "tailscale-up.service" ];
      after = [ "tailscale-up.service" ];
    };
  };
}
