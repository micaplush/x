{ config, globalConfig, lib, localEval, name, ... }:

let
  cfg = config.x.global.agenix;

  toplevelConfig = config;
  hostname = name;

  jsonMakeFunctionCall = name: arguments: {
    __secretsGeneratorType = "functionCall";
    inherit name arguments;
  };

  jsonLib = {
    fmt = format: args: jsonMakeFunctionCall "fmt" {
      inherit format args;
    };

    hashArgon2id = data: memory: iterations: parallelism: jsonMakeFunctionCall "hashArgon2id" {
      inherit data memory iterations parallelism;
    };

    hashBcrypt = data: rounds: jsonMakeFunctionCall "hashBcrypt" {
      inherit data rounds;
    };

    readSecret = name: jsonMakeFunctionCall "readSecret" {
      inherit name;
    };
  };

  jsonCoerceContent = content:
    if builtins.isFunction content
    then content { inherit jsonLib; }
    else content;

  generationOptions = secretName: {
    json = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          content = lib.mkOption {
            type = lib.types.coercedTo lib.types.anything jsonCoerceContent lib.types.anything;
          };
        };
      });
    };

    random = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          length = lib.mkOption {
            default = 64;
            type = lib.types.ints.unsigned;
          };

          charsets = lib.mapAttrs
            (name: defaultEnabled: lib.mkOption {
              default = defaultEnabled;
              type = lib.types.bool;
            })
            {
              lowercase = true;
              numbers = true;
              special = true;
              uppercase = true;
            };
        };
      });
    };

    script = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.submodule ({ config, ... }: {
        options = {
          runtimeInputs = lib.mkOption {
            default = pkgs: [ pkgs.coreutils ];
            type = with lib.types; functionTo (listOf package);
          };

          script = lib.mkOption {
            type = lib.types.str;
          };

          program = lib.mkOption {
            readOnly = localEval;
            type = with lib.types; functionTo str;
          };
        };

        config = lib.optionalAttrs localEval {
          program =
            let
              name = "secret-generator-${lib.replaceStrings ["/"] ["_"] secretName}";
            in
            pkgs: lib.getExe (pkgs.writeShellApplication {
              inherit name;

              runtimeInputs = config.runtimeInputs pkgs;

              text = ''
                TMP_DIR=$(mktemp --tmpdir="$XDG_RUNTIME_DIR" --directory secrets-generator.XXXXXX)
                readonly TMP_DIR

                # shellcheck disable=SC2034 # It's okay if this variable stays unused.
                WORKING_DIR="$PWD"
                # shellcheck disable=SC2034 # It's okay if this variable stays unused.
                readonly WORKING_DIR

                function cleanup {
                  rm -r "$TMP_DIR"
                }
                trap cleanup EXIT

                ${config.script}
              '';

              meta.mainProgram = name;
            });
        };
      }));
    };

    template = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          content = lib.mkOption {
            type = lib.types.str;
          };

          data = lib.mkOption {
            default = { };
            type = lib.types.attrs;
          };
        };
      });
    };
  };
in
{
  options.x.global.agenix = {
    publicKeys = lib.mkOption {
      default = { };
      type = with lib.types; attrsOf (listOf str);
    };

    secrets = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          generation = generationOptions name;
        };
      }));
    };

    secretMounts = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          secret = lib.mkOption {
            default = name;
            type = lib.types.str;
          };

          host = lib.mkOption {
            type = lib.types.str;
          };

          owner = lib.mkOption {
            type = lib.types.str;
          };

          group = lib.mkOption {
            type = lib.types.str;
          };

          mode = lib.mkOption {
            default = "u=r,go=";
            type = lib.types.str;
          };

          path = lib.mkOption {
            type = lib.types.str;
          };
        };

        config = lib.optionalAttrs localEval {
          host = lib.mkDefault hostname;
          owner = lib.mkDefault toplevelConfig.users.users.root.name;
          group = lib.mkDefault toplevelConfig.users.users.root.group;
          path = lib.mkDefault "${toplevelConfig.age.secretsDir}/${name}";
        };
      }));
    };
  };

  config = lib.optionalAttrs localEval {
    assertions = lib.flatten [
      (lib.mapAttrsToList
        (secretName: secret: {
          assertion = lib.pipe secret.generation [
            builtins.attrValues
            (builtins.filter (v: v != null))
            (genMethods: (builtins.length genMethods) <= 1)
          ];
          message = "Secret ${secretName} specifies multiple methods for secret generation; only zero or one method(s) can be specified at the same time";
        })
        cfg.secrets)

      (lib.mapAttrsToList
        (mountName: { host, secret, ... }: [
          {
            assertion = globalConfig.agenix.publicKeys ? ${host};
            message = "Hostname ${host} in secret mount named ${mountName} does not exist";
          }
          {
            assertion = globalConfig.agenix.secrets ? ${secret};
            message = "Secret ${secret} in secret mount named ${mountName} does not exist";
          }
        ])
        cfg.secretMounts)
    ];
  };
}
