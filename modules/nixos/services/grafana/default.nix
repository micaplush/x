{ config, globalConfig, lib, self', ... }:

let
  cfg = config.x.services.grafana;

  grafanaDataDir = "${config.x.base.filesystems.persistDirectory}/grafana-data";
  grafanaURL = "http://${globalConfig.netsrv.services.grafana.fqdn}";
in
{
  options.x.services.grafana.enable = lib.mkEnableOption "Grafana";

  config = lib.mkIf cfg.enable {
    x.global.agenix.secrets."grafana-passwords/admin" = {
      generation.random = { };
    };

    x.global.agenix.secretMounts = {
      "grafana-passwords/admin" = {
        owner = config.users.users.grafana.name;
        group = config.users.groups.grafana.name;
      };

      "prometheus-passwords/grafana" = {
        owner = config.users.users.grafana.name;
        group = config.users.groups.grafana.name;
      };
    };

    x.base.localport.decls = {
      grafana = { };
      grafana-ntfy = { };
    };

    x.global.prometheus.users = [ "grafana" ];

    services.grafana = {
      enable = true;
      dataDir = grafanaDataDir;

      settings = {
        analytics = {
          reporting_enabled = false;
          feedback_links_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };

        security.admin_password = "$__file{${globalConfig.agenix.secretMounts."grafana-passwords/admin".path}}";

        server = {
          http_port = config.x.base.localport.ports.grafana;
          root_url = grafanaURL;
          csrf_trusted_origins = [ grafanaURL ];
        };

        users.home_page = "/d/${(builtins.fromJSON (builtins.readFile ./dashboards/node-exporter-full.json)).uid}";
      };

      provision = {
        enable = true;

        alerting = {
          contactPoints.settings = {
            apiVersion = 1;
            contactPoints = lib.singleton {
              orgId = 1;
              name = "ntfy";
              receivers = lib.singleton {
                uid = "ntfy";
                type = "webhook";
                settings = {
                  httpMethod = "POST";
                  url = "http://127.0.0.1:${builtins.toString config.x.base.localport.ports.grafana-ntfy}";
                };
              };
            };
          };

          policies.settings = {
            apiVersion = 1;
            policies = lib.singleton {
              orgId = 1;
              receiver = "ntfy";
              group_by = [ "grafana_folder" "alertname" ];
            };
          };

          rules.path = ./alerting-rules.yml;
        };

        dashboards.settings = {
          apiVersion = 1;
          providers = lib.singleton {
            name = "default";
            options = {
              path = ./dashboards;
            };
            updateIntervalSeconds = 999999;
          };
        };

        datasources.settings.datasources = lib.singleton {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${builtins.toString config.x.base.localport.ports.prometheus}";
          basicAuth = true;
          basicAuthUser = "grafana";
          secureJsonData.basicAuthPassword = "$__file{${globalConfig.agenix.secretMounts."prometheus-passwords/grafana".path}}";
        };
      };
    };

    system.activationScripts.grafana-data-dir.text = ''
      mkdir -p ${grafanaDataDir}
      chown ${config.users.users.grafana.name}:${config.users.groups.grafana.name} ${grafanaDataDir}
      chmod u=rwx,go= ${grafanaDataDir}
    '';

    x.server.caddy.services.grafana.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString config.x.base.localport.ports.grafana} {
        header_up Host "${globalConfig.netsrv.services.grafana.fqdn}"
        header_up Origin "${grafanaURL}"
      }
    '';

    systemd.services.grafana-ntfy = {
      enable = true;
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${lib.getExe self'.packages.grafana-ntfy} -allow-insecure -ntfy-url http://127.0.0.1:${builtins.toString config.x.base.localport.ports.ntfy}/grafana -port ${builtins.toString config.x.base.localport.ports.grafana-ntfy}";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
