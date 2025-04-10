{ config, globalConfig, lib, name, ... }:

let
  cfg = config.x.services.prometheus;

  prometheusUser = config.users.users.prometheus.name;
  prometheusGroup = config.users.users.prometheus.group;
in
{
  options.x.services.prometheus = {
    enable = lib.mkEnableOption "Prometheus";
  };

  config = lib.mkIf cfg.enable {
    x.base.filesystems.persistentDirectories = [
      "/var/lib/${config.services.prometheus.stateDir}"
    ];

    x.base.restic.exclude = [
      "${config.x.base.filesystems.persistDirectory}/var/lib/prometheus2"
    ];

    x.base.localport.decls.prometheus = { };

    x.global.agenix.secrets = lib.mkMerge [
      {
        prometheus-web-config = {
          generation.json.content = { jsonLib, ... }: {
            basic_auth_users = lib.pipe globalConfig.prometheus.users [
              (builtins.map (username: {
                name = username;
                value = jsonLib.hashBcrypt (jsonLib.readSecret "prometheus-passwords/${username}") 10;
              }))
              lib.listToAttrs
            ];
          };
        };
      }

      (lib.pipe globalConfig.prometheus.users [
        (builtins.map (username: {
          name = "prometheus-passwords/${username}";
          value = {
            generation.random.charsets.special = false;
          };
        }))
        lib.listToAttrs
      ])
    ];

    x.global.agenix.secretMounts = lib.mkMerge [
      {
        prometheus-web-config = {
          owner = prometheusUser;
          group = prometheusGroup;
        };
      }

      (lib.mapAttrs'
        (scrapeConfigName: scrapeConfig: {
          name = scrapeConfig.basicAuth.passwordSecret;
          value = {
            owner = prometheusUser;
            group = prometheusGroup;
          };
        })
        globalConfig.prometheus.scrapeConfigs)
    ];

    x.global.netsrv.access = lib.pipe globalConfig.prometheus.scrapeConfigs [
      (lib.mapAttrsToList (scrapeConfigName: scrapeConfig:
        (builtins.map
          (target: {
            inherit (target) service;
            host = name;
          })
          scrapeConfig.targets)))
      lib.flatten
    ];

    services.prometheus = {
      enable = true;
      extraFlags = [ "--web.config.file=${globalConfig.agenix.secretMounts.prometheus-web-config.path}" ];
      port = config.x.base.localport.ports.prometheus;
      retentionTime = "7d";
      webExternalUrl = "http://${globalConfig.netsrv.services.prometheus.fqdn}/";

      scrapeConfigs = lib.mapAttrsToList
        (scrapeConfigName: scrapeConfig: {
          job_name = scrapeConfigName;
          basic_auth = {
            username = scrapeConfig.basicAuth.username;
            password_file = globalConfig.agenix.secretMounts.${scrapeConfig.basicAuth.passwordSecret}.path;
          };
          static_configs = lib.singleton {
            targets = builtins.map
              (target:
                let
                  service = globalConfig.netsrv.services.${target.service};
                in
                "${service.fqdn}:${builtins.toString service.ports.${target.port}.port}")
              scrapeConfig.targets;
          };
        })
        globalConfig.prometheus.scrapeConfigs;
    };

    x.server.caddy.services.prometheus.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString config.x.base.localport.ports.prometheus}
    '';
  };
}
