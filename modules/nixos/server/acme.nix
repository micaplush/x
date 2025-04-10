{ config, globalConfig, lib, ... }:

let
  cfg = config.x.server.acme;

  acmeWebrootPath = "/var/lib/acme-challenge";
  acmeWebroot = certName: "${acmeWebrootPath}/${certName}";
in
{
  options.x.server.acme = {
    certs = lib.mkOption {
      default = { };
      type =
        let
          hostConfig = config;
        in
        lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
          options = {
            commonName = lib.mkOption {
              default = name;
              type = lib.types.str;
            };

            directory = lib.mkOption {
              readOnly = true;
              type = lib.types.str;
            };

            options = lib.mkOption {
              default = { };
              type = lib.types.attrs;
            };
          };

          config = {
            directory = hostConfig.security.acme.certs.${config.commonName}.directory;
          };
        }));
    };
  };

  config = lib.mkIf (config.x.server.enable && cfg.certs != { }) {
    x.base.filesystems.persistentDirectories = [
      "/var/lib/acme"
    ];

    x.global.netsrv.services = lib.mapAttrs'
      (certName: { commonName, ... }: {
        name = commonName;
        value.ports.acme = {
          port = 80;
          shared = true;
        };
      })
      cfg.certs;

    services.caddy.enable = true;

    services.caddy.virtualHosts = lib.mapAttrs'
      (certName: { commonName, ... }: {
        name = "http://${commonName}.in.tbx.at";
        value = {
          listenAddresses = [ globalConfig.netsrv.services.${commonName}.address ];
          extraConfig = ''
            root * ${acmeWebroot certName}
            file_server
            header /* >Cache-Control no-store
          '';
        };
      })
      cfg.certs;

    security.acme.certs = lib.mapAttrs'
      (certName: { commonName, options, ... }: {
        name = commonName;
        value = options // {
          domain = "${commonName}.in.tbx.at";
          webroot = acmeWebroot certName;
        };
      })
      cfg.certs;

    systemd.services = lib.mapAttrs'
      (certName: { ... }: {
        name = "acme-${certName}";
        value = {
          after = [ "tailscale-up.service" ];
          requires = [ "tailscale-up.service" ];
        };
      })
      cfg.certs;

    systemd.tmpfiles.rules = lib.pipe cfg.certs [
      (lib.mapAttrsToList (certName: { commonName, ... }: [
        "d ${acmeWebroot certName} 1775 ${config.users.users.acme.name} ${config.security.acme.certs.${commonName}.group} -"
      ]))
      lib.flatten
    ];
  };
}
