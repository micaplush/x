{ lib, localEval, ... }:

{
  options.x.global.oidc.clients = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        secret = lib.mkOption {
          readOnly = localEval;
          type = lib.types.str;
        };

        settings = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            freeformType = lib.types.attrs;
            options = {
              pre_configured_consent_duration = lib.mkOption {
                default = "1 month";
                type = lib.types.str;
              };
            };
          };
        };
      };

      config = lib.optionalAttrs localEval {
        secret = "oidc-client-secrets/${name}";
      };
    }));
  };
}
