{ config, globalConfig, lib, pkgs, self', ... }:

let
  cfg = config.x.services.paperless;

  dataDir = "${config.x.base.filesystems.persistDirectory}/paperless-data";

  mkIMAPConsumeService = { emailLocalPart, tag ? null, ... }:
    let
      emailAddress = "${emailLocalPart}@systems.tbx.at";
      passwordSecret = globalConfig.email.accounts.${emailAddress}.secrets.imap;
      passwordSecretPath = globalConfig.agenix.secretMounts.${passwordSecret}.path;
    in
    {
      path = [ self'.packages.paperless-imap-consume ];
      script = ''
        paperless-imap-consume \
          -server ${globalConfig.netsrv.services.imap.fqdn}:${builtins.toString globalConfig.netsrv.services.imap.ports.imaps.port} \
          -username ${emailAddress} \
          -password-file ${passwordSecretPath} \
          -consume-dir ${config.services.paperless.consumptionDir}${lib.optionalString (tag != null) "/${tag}"} \
          -delete \
          -log-level debug
      '';

      serviceConfig = {
        User = config.users.users.paperless.name;
        group = config.users.users.paperless.group;
        Restart = "on-failure";
      };

      wantedBy = [ "multi-user.target" ];

      after = [ "network.target" ];
      wants = [ "network.target" ];
    };
in
{
  options.x.services.paperless.enable = lib.mkEnableOption "Paperless";

  config = lib.mkIf cfg.enable {
    x.global.agenix.secrets = {
      "paperless/environment-file" = {
        generation.template.content = ''
          PAPERLESS_SOCIALACCOUNT_PROVIDERS='{{ stringReplace (fmt "%s" (readSecret "paperless/sso-config-file")) "'" "\\'" -1 }}'
        '';
      };

      "paperless/sso-config-file" = {
        generation.json.content = { jsonLib, ... }: {
          openid_connect = {
            APPS = [
              {
                client_id = "paperless";
                name = "Authelia";
                provider_id = "authelia";
                secret = jsonLib.fmt "%s" [ (jsonLib.readSecret "oidc-client-secrets/paperless") ];
                settings = {
                  server_url = "https://${globalConfig.netsrv.services.sso.fqdn}";
                  token_auth_method = "client_secret_basic";
                };
              }
            ];
            OAUTH_PKCE_ENABLED = true;
            SCOPE = [ "openid" "profile" "email" ];
          };
        };
      };

      "paperless/labelgen-password" = {
        generation.random = { };
      };
    };

    x.global.agenix.secretMounts = {
      ${globalConfig.email.accounts."paperless@systems.tbx.at".secrets.imap} = {
        owner = config.users.users.paperless.name;
        group = config.users.users.paperless.group;
      };

      ${globalConfig.email.accounts."paperless-asn@systems.tbx.at".secrets.imap} = {
        owner = config.users.users.paperless.name;
        group = config.users.users.paperless.group;
      };

      "paperless/environment-file" = { };

      "paperless/labelgen-password" = {
        owner = config.users.users.paperless.name;
        group = config.users.users.paperless.group;
      };
    };

    services.paperless = {
      inherit dataDir;

      enable = true;
      port = config.x.base.localport.ports.paperless;

      settings = {
        # Hack to make Paperless accept the internal CA
        REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";

        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_CONSUMER_RECURSIVE = true;
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_OCR_LANGUAGE = "deu+eng";

        PAPERLESS_POST_CONSUME_SCRIPT = lib.getExe (pkgs.writeShellApplication {
          name = "paperless-post-consume";
          runtimeInputs = [ self'.packages.paperless-labelgen ];
          text = ''
            paperless-labelgen \
              -url https://${globalConfig.netsrv.services.paperless.fqdn} \
              -username labelgen \
              -password-file ${globalConfig.agenix.secretMounts."paperless/labelgen-password".path} \
              -printer ${config.x.peripherals.labelprinter.name} \
              -assign-asn \
              -document-id "$DOCUMENT_ID"
          '';
        });
      };
    };

    x.global.oidc.clients.paperless = {
      settings = {
        client_name = "Paperless";
        pkce_challenge_method = "S256";
        public = false;
        redirect_uris = [ "https://${globalConfig.netsrv.services.paperless.fqdn}/accounts/oidc/authelia/login/callback/" ];
        scopes = [
          "openid"
          "profile"
          "email"
          "groups"
        ];
        require_pkce = true;
        token_endpoint_auth_method = "client_secret_basic";
        userinfo_signed_response_alg = "none";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0700 ${config.users.users.paperless.name} ${config.users.users.paperless.group} -"
    ];

    # Hack to pass the OIDC client secret without including it in the Nix store
    systemd.services.paperless-web.serviceConfig.EnvironmentFile = globalConfig.agenix.secretMounts."paperless/environment-file".path;

    x.base.localport.decls.paperless = { };

    x.server.caddy.services.paperless.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString config.x.base.localport.ports.paperless} {
          header_down Referrer-Policy "strict-origin-when-cross-origin"
      }
    '';

    environment.systemPackages = [ self'.packages.paperless-labelgen ];

    x.global.email.accounts = {
      "paperless@systems.tbx.at" = {
        permissions.receive = true;
      };

      "paperless-asn@systems.tbx.at" = {
        permissions.receive = true;
      };
    };

    systemd.services.paperless-imap-consume-asn = mkIMAPConsumeService {
      emailLocalPart = "paperless-asn";
      tag = "assign_asn";
    };

    systemd.services.paperless-imap-consume-noasn = mkIMAPConsumeService {
      emailLocalPart = "paperless";
    };
  };
}
