{ config, globalConfig, lib, name, ... }:

let
  configSecretName = "node-exporter-configs/${name}";
  passwordSecretName = "node-exporter-passwords/${name}";

  service = globalConfig.netsrv.services.${serviceName};
  serviceName = "node-exporter.${name}";
in
{
  config = lib.mkIf config.x.server.enable {
    x.global.netsrv.services.${serviceName} = {
      ports.http.port = 6500;
    };

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      extraFlags = [ "--web.config.file=${globalConfig.agenix.secretMounts.${configSecretName}.path}" ];
      port = service.ports.http.port;
    };

    x.global.agenix.secrets = {
      ${passwordSecretName}.generation.random = { };

      ${configSecretName} = {
        generation.json.content = { jsonLib, ... }: {
          basic_auth_users.prometheus = jsonLib.hashBcrypt (jsonLib.readSecret passwordSecretName) 10;
        };
      };
    };

    x.global.agenix.secretMounts.${configSecretName} = {
      owner = config.services.prometheus.exporters.node.user;
      group = config.services.prometheus.exporters.node.group;
    };

    x.global.prometheus.scrapeConfigs."${name}.node" = {
      basicAuth = {
        username = "prometheus";
        passwordSecret = passwordSecretName;
      };
      targets = lib.singleton {
        service = serviceName;
        port = "http";
      };
    };
  };
}
