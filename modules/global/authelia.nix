{ lib, ... }:

{
  options.x.global.authelia = {
    users = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          disabled = lib.mkOption {
            default = false;
            type = lib.types.bool;
          };

          displayName = lib.mkOption {
            type = lib.types.str;
          };
        };
      });
    };
  };
}
