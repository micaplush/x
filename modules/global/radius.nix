{ lib, localEval, ... }:

{
  options.x.global.radius = {
    clients = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          ipaddr = lib.mkOption {
            type = lib.types.str;
          };

          secret = lib.mkOption {
            readOnly = localEval;
            type = lib.types.str;
          };
        };

        config = {
          secret = "radius/client-secrets/${name}";
        };
      }));
    };

    users = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          passwordSecret = lib.mkOption {
            readOnly = localEval;
            type = lib.types.str;
          };

          vlan = lib.mkOption {
            default = null;
            type = with lib.types; nullOr (ints.between 1 4096);
          };
        };

        config = {
          passwordSecret = "radius/user-passwords/${name}";
        };
      }));
    };
  };
}
