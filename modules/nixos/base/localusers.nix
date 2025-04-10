{ config, globalConfig, lib, name, ... }:

let
  cfg = config.x.base.localusers;
in
{
  options.x.base.localusers = {
    rootAuthorizedKeys = lib.mkOption {
      default = [ ];
      type = with lib.types; listOf str;
    };

    users = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          authorizedKeys = lib.mkOption {
            default = [ ];
            type = with lib.types; listOf str;
          };

          isAdmin = lib.mkOption {
            default = false;
            type = lib.types.bool;
          };
        };
      });
    };
  };

  config = {
    x.base.localusers = {
      rootAuthorizedKeys = globalConfig.users.rootAuthorizedKeys;

      users = lib.pipe globalConfig.users.accounts [
        (lib.filterAttrs (username: user: user.local.enable))
        (lib.mapAttrs (username: user: {
          inherit (user) isAdmin;
          inherit (user.local) authorizedKeys;
        }))
      ];
    };

    x.global.agenix.secrets = lib.pipe cfg.users [
      (lib.mapAttrsToList (username: user: {
        "user-passwords/${username}" = {
          generation.random = { };
        };

        "user-password-hashes/${username}" = {
          generation.template = {
            data.username = username;
            content = ''{{ hashBcrypt (readSecret (fmt "user-passwords/%s" .username) ) 10 }}'';
          };
        };
      }))
      lib.mkMerge
    ];

    x.global.agenix.secretMounts = lib.mapAttrs'
      (username: user: {
        name = "user-password-hashes/${username}/${name}";
        value = {
          secret = "user-password-hashes/${username}";
        };
      })
      cfg.users;

    users.mutableUsers = false;

    users.users = lib.mkMerge [
      (lib.mapAttrs
        (username: user: {
          isNormalUser = true;

          extraGroups = lib.optionals user.isAdmin [
            "wheel"
            config.users.groups.networkmanager.name
          ];

          hashedPasswordFile = globalConfig.agenix.secretMounts."user-password-hashes/${username}/${name}".path;
          openssh.authorizedKeys.keys = user.authorizedKeys;
        })
        cfg.users)

      {
        root = {
          password = null;
          openssh.authorizedKeys.keys = cfg.rootAuthorizedKeys;
        };
      }
    ];
  };
}
