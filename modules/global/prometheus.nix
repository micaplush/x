{ lib, ... }:

{
  options.x.global.prometheus = {
    scrapeConfigs = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          basicAuth = {
            username = lib.mkOption {
              type = lib.types.str;
            };
            passwordSecret = lib.mkOption {
              type = lib.types.str;
            };
          };

          targets = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                service = lib.mkOption {
                  type = lib.types.str;
                };
                port = lib.mkOption {
                  type = lib.types.str;
                };
              };
            });
          };
        };
      });
    };

    users = lib.mkOption {
      default = [ ];
      type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
    };
  };
}
