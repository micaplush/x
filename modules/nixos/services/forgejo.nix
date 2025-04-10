{ config, globalConfig, pkgs, lib, ... }:

let
  cfg = config.x.services.forgejo;
in
{
  options.x.services.forgejo.enable = lib.mkEnableOption "Forgejo";

  config = lib.mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      stateDir = "${config.x.base.filesystems.persistDirectory}/forgejo-state";

      lfs.enable = true;

      settings = {
        DEFAULT.APP_NAME = "Forgejo";

        server = {
          DOMAIN = globalConfig.netsrv.services.forge.fqdn;
          LANDING_PAGE = "login";
          PROTOCOL = "http+unix";
          ROOT_URL = "https://${globalConfig.netsrv.services.forge.fqdn}";
        };

        openid = {
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = true;
          WHITELISTED_URIS = globalConfig.netsrv.services.sso.fqdn;
        };

        service = {
          DISABLE_REGISTRATION = true;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          SHOW_REGISTRATION_BUTTON = false;
        };

        session.COOKIE_SECURE = true;
      };
    };

    x.server.caddy.services.forge.extraConfig = ''
      reverse_proxy unix/${config.services.forgejo.settings.server.HTTP_ADDR}
    '';

    x.global.oidc.clients.forgejo = {
      settings = {
        client_name = "Forgejo";
        public = false;
        redirect_uris = [ "https://${globalConfig.netsrv.services.forge.fqdn}/user/oauth2/authelia/callback" ];
        scopes = [
          "openid"
          "profile"
          "email"
        ];
        token_endpoint_auth_method = "client_secret_basic";
        userinfo_signed_response_alg = "none";
      };
    };

    environment.systemPackages = [ pkgs.forgejo ];
  };
}
