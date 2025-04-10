{ config, lib, localEval, ... }:

let
  cfg = config.x.global.users;
in
{
  options.x.global.users = {
    accounts = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          displayName = lib.mkOption {
            default = name;
            type = lib.types.str;
          };

          isAdmin = lib.mkOption {
            default = false;
            type = lib.types.bool;
          };

          local = {
            enable = lib.mkOption {
              default = true;
              type = lib.types.bool;
            };

            authorizedKeys = lib.mkOption {
              default = [ ];
              type = with lib.types; listOf str;
            };
          };

          prometheus.enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
          };

          radicale.enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
          };

          sso.enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
          };
        };
      }));
    };

    rootAuthorizedKeys = lib.mkOption {
      default = [ ];
      type = with lib.types; listOf str;
    };
  };

  config = lib.optionalAttrs (!localEval) {
    x.global.authelia.users = lib.mapAttrs
      (username: user: {
        inherit (user) displayName;
        disabled = !user.sso.enable;
      })
      cfg.accounts;

    x.global.prometheus.users = lib.pipe cfg.accounts [
      (lib.filterAttrs (username: user: user.prometheus.enable))
      builtins.attrNames
    ];

    x.global.radicale.users = lib.pipe cfg.accounts [
      (lib.filterAttrs (username: user: user.radicale.enable))
      builtins.attrNames
    ];
  };
}
