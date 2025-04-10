{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.authelia;

  stateDir = "${config.x.base.filesystems.persistDirectory}/authelia";
  dbFile = "${stateDir}/storage.sqlite";
in
{
  options.x.services.authelia = {
    enable = lib.mkEnableOption "Authelia";
  };

  config = lib.mkIf cfg.enable {
    x.global.agenix.secrets = lib.mkMerge [
      (lib.mapAttrs'
        (clientID: client: {
          name = client.secret;
          value = {
            generation.random = {
              charsets.special = false;
              length = 72;
            };
          };
        })
        globalConfig.oidc.clients)

      (lib.mapAttrs'
        (clientID: client: {
          name = "oidc-client-secret-hashes/${clientID}";
          value = {
            generation.template = {
              data.plainSecret = "oidc-client-secrets/${clientID}";
              content = "{{ hashArgon2id (readSecret .plainSecret) 65536 3 4 }}"; # These hash parameters should match those used by the `authelia` CLI.
            };
          };
        })
        globalConfig.oidc.clients)

      (lib.mapAttrs'
        (username: user: {
          name = "authelia/passwords/${username}";
          value = {
            generation.random = { };
          };
        })
        globalConfig.authelia.users)

      {
        "authelia/jwk-private-key" = {
          generation.script = {
            runtimeInputs = pkgs: with pkgs; [ authelia coreutils ];
            script = ''
              cd "$TMP_DIR"
              authelia crypto certificate rsa generate >&2
              cat private.crt
            '';
          };
        };

        "authelia/jwt-secret" = {
          generation.random.charsets.special = false;
        };

        "authelia/backend-file" = {
          generation.json.content = { jsonLib, ... }: {
            users = lib.mapAttrs
              (username: user: {
                inherit (user) disabled;
                displayname = user.displayName;
                password = jsonLib.hashArgon2id (jsonLib.readSecret "authelia/passwords/${username}") 65536 3 4;
              })
              globalConfig.authelia.users;
          };
        };

        "authelia/storage-encryption-key" = {
          generation.random = { };
        };
      }
    ];

    x.global.agenix.secretMounts =
      let
        owner = config.users.users.authelia-main.name;
        group = config.users.users.authelia-main.group;
      in
      lib.mkMerge [
        (lib.mapAttrs'
          (clientID: client: {
            name = "oidc-client-secret-hashes/${clientID}";
            value = {
              inherit owner group;
            };
          })
          globalConfig.oidc.clients)

        {
          "authelia/jwk-private-key" = {
            inherit owner group;
          };

          "authelia/jwt-secret" = {
            inherit owner group;
          };

          "authelia/backend-file" = {
            inherit owner group;
          };

          "authelia/storage-encryption-key" = {
            inherit owner group;
          };
        }
      ];

    services.authelia.instances.main = {
      enable = true;

      secrets = {
        jwtSecretFile = globalConfig.agenix.secretMounts."authelia/jwt-secret".path;
        storageEncryptionKeyFile = globalConfig.agenix.secretMounts."authelia/storage-encryption-key".path;
      };

      environmentVariables.X_AUTHELIA_CONFIG_FILTERS = "template";

      settings = {
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = [ globalConfig.netsrv.services.sso.fqdn ];
              policy = "bypass";
            }
            {
              domain = [ "*.in.tbx.at" ];
              policy = "two_factor";
            }
          ];
        };

        authentication_backend.file.path = globalConfig.agenix.secretMounts."authelia/backend-file".path;

        default_2fa_method = "totp";

        identity_providers.oidc.clients = lib.mapAttrsToList
          (clientID: client:
            client.settings // {
              client_id = clientID;
              client_secret = ''{{- fileContent "${globalConfig.agenix.secretMounts."oidc-client-secret-hashes/${clientID}".path}" -}}'';
            })
          globalConfig.oidc.clients;

        notifier = {
          disable_startup_check = false;
          filesystem.filename = "/var/lib/authelia-main/notification.txt";
        };

        server = {
          host = "127.0.0.1";
          port = config.x.base.localport.ports.authelia;
          disable_healthcheck = true;
        };

        session.cookies = [
          {
            domain = "in.tbx.at";
            authelia_url = "https://${globalConfig.netsrv.services.sso.fqdn}";
          }
        ];

        storage.local.path = dbFile;

        totp.issuer = "tbx.at Internal";
      };

      # YAML snippet taken from https://www.authelia.com/configuration/prologue/security-sensitive-values/#multi-line-value
      settingsFiles = lib.singleton (builtins.toFile "authelia-jwk-key-config" ''
        identity_providers:
          oidc:
            jwks:
              - key: {{ secret "${globalConfig.agenix.secretMounts."authelia/jwk-private-key".path}" | mindent 10 "|" | msquote }}
      '');
    };

    systemd.services.authelia-main.serviceConfig.ReadWritePaths = [ stateDir ];

    x.base.localport.decls.authelia = { };

    x.server.caddy.services.sso.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString config.x.base.localport.ports.authelia}
    '';

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 ${config.users.users.authelia-main.name} ${config.users.users.authelia-main.group} -"
    ];
  };
}
