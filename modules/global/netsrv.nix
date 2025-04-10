{ config, globalConfig, lib, localEval, name, ... }:

let
  cfg = config.x.global.netsrv;
  hostname = name;

  servicesType = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
    options = {
      accessFromAllHosts = lib.mkOption {
        default = false;
        type = lib.types.bool;
      };

      host = lib.mkOption {
        type = lib.types.str;
      };

      address = lib.mkOption {
        type = lib.types.str;
      };

      ports = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
            };

            protocol = lib.mkOption {
              default = "tcp";
              type = lib.types.enum [ "tcp" "udp" ];
            };

            shared = lib.mkOption {
              default = false;
              type = lib.types.bool;
            };
          };
        });
      };

      fqdn = lib.mkOption {
        readOnly = localEval;
        type = lib.types.str;
      };

      publishDNS = lib.mkOption {
        default = true;
        type = lib.types.bool;
      };
    };

    config = lib.optionalAttrs localEval {
      host = lib.mkDefault hostname;
      address = lib.mkDefault globalConfig.netsrv.hosts.${config.host};
      fqdn = lib.mkDefault "${name}.in.tbx.at";
    };
  }));
in
{
  options.x.global.netsrv = {
    access = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
          };

          service = lib.mkOption {
            type = lib.types.str;
          };
        };

        config = lib.optionalAttrs localEval {
          host = lib.mkDefault hostname;
        };
      });
    };

    hosts = lib.mkOption {
      type = with lib.types; attrsOf str;
    };

    services = lib.mkOption {
      default = { };
      type = servicesType;
    };
  };

  config = lib.optionalAttrs localEval {
    assertions = lib.concatLists [
      (lib.pipe cfg.services [
        (lib.mapAttrsToList (hostname: service: [
          {
            assertion = globalConfig.netsrv.hosts ? ${service.host};
            message = "Hostname ${service.host} of service ${hostname} does not exist";
          }
        ]))
        lib.flatten
      ])

      (lib.pipe globalConfig.netsrv.access [
        (builtins.map ({ host, service, ... }:
          let
            prefix = "Access from host ${host} to service ${service}";
          in
          [
            {
              assertion = globalConfig.netsrv.hosts ? ${host};
              message = "${prefix}: host does not exist";
            }
            {
              assertion = globalConfig.netsrv.services ? ${service};
              message = "${prefix}: service does not exist";
            }
          ]))
        lib.flatten
      ])

      (
        let
          portAllocations = lib.pipe cfg.services [
            (lib.mapAttrsToList (hostname: service:
              lib.mapAttrsToList
                (portName: port: {
                  ${service.host}.${port.protocol}.${builtins.toString port.port}.${builtins.toString port.shared}.${hostname} = true;
                })
                service.ports
            ))
            lib.flatten
            (lib.fold lib.recursiveUpdate { })
          ];

          assertions = lib.pipe portAllocations [
            (lib.mapAttrsToList (host: protocols:
              (lib.mapAttrsToList
                (protocol: ports:
                  (lib.mapAttrsToList
                    (port: services:
                      let
                        s = shares: lib.optionals (services ? ${builtins.toString shares}) (builtins.attrNames services.${builtins.toString shares});
                        sharePort = s true;
                        takePort = s false;
                      in
                      [
                        {
                          assertion = builtins.length takePort <= 1;
                          message = "Port ${builtins.toString port}/${protocol} on ${host} is assigned to multiple services which do not allow port sharing (${builtins.concatStringsSep ", " takePort})";
                        }
                        {
                          assertion = builtins.length takePort == 0 || (builtins.length sharePort == 0);
                          message = "Port ${builtins.toString port}/${protocol} on ${host} is assigned to more than one service, one of which does not allow port sharing (sharing: ${builtins.concatStringsSep ", " sharePort}; non-sharing: ${builtins.concatStringsSep ", " takePort})";
                        }
                      ])
                    ports))
                protocols)
            ))
            lib.flatten
          ];
        in
        assertions
      )
    ];

    x.global.netsrv.access = lib.pipe cfg.services [
      (lib.filterAttrs (serviceName: service: service.accessFromAllHosts))
      (lib.mapAttrsToList (serviceName: service:
        lib.mapAttrsToList
          (hostname: address: {
            host = hostname;
            service = serviceName;
          })
          globalConfig.netsrv.hosts))
      lib.flatten
    ];
  };
}
