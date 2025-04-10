{ config, globalConfig, lib, ... }:

let
  cfg = config.x.server.caddy;
  dataDir = "${config.x.base.filesystems.persistDirectory}/caddy-data";
in
{
  options.x.server.caddy.services = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        extraConfig = lib.mkOption {
          default = "";
          type = lib.types.lines;
        };
      };
    });
  };

  config = lib.mkMerge [
    (lib.mkIf (config.x.server.enable && config.services.caddy.enable) {
      services.caddy = {
        inherit dataDir;
        email = config.security.acme.defaults.email;
        acmeCA = config.security.acme.defaults.server;
      };

      systemd.services.caddy = {
        after = [ "tailscale-up.service" ];
        requires = [ "tailscale-up.service" ];
      };

      system.activationScripts.caddy-data-dir.text = ''
        mkdir -p ${dataDir}
        chown ${config.services.caddy.user}:${config.services.caddy.group} ${dataDir}
        chmod u=rwx,go=rx ${dataDir}
      '';
    })

    (lib.mkIf (config.x.server.enable && cfg.services != { }) {
      services.caddy.enable = true;

      services.caddy.virtualHosts = lib.mapAttrs
        (name: srv:
          let
            netsrv = globalConfig.netsrv.services.${name};
          in
          {
            inherit (srv) extraConfig;
            hostName = netsrv.fqdn;
            listenAddresses = [ netsrv.address ];
          })
        cfg.services;

      x.global.netsrv.services = lib.mapAttrs
        (name: srv: {
          ports = {
            https = { port = 443; shared = true; };
            http = { port = 80; shared = true; };
          };
        })
        cfg.services;
    })
  ];
}
