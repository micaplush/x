{ lib, localEval, ... }:

{
  options.x.global.restic = {
    users = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          name = lib.mkOption {
            readOnly = localEval;
            type = lib.types.str;
          };

          passwordSecret = lib.mkOption {
            readOnly = localEval;
            type = lib.types.str;
          };

          repositories =
            let
              username = name;
            in
            lib.mkOption {
              default = { };
              type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
                options = {
                  secrets = {
                    password = lib.mkOption {
                      readOnly = localEval;
                      type = lib.types.str;
                    };

                    url = lib.mkOption {
                      readOnly = localEval;
                      type = lib.types.str;
                    };
                  };
                };

                config = {
                  secrets = {
                    password = "restic/repo-password/${username}/${name}";
                    url = "restic/repo-url/${username}/${name}";
                  };
                };
              }));
            };
        };

        config = {
          inherit name;
          passwordSecret = "restic/server-password/${name}";
        };
      }));
    };
  };
}
