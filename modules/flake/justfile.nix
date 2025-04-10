{ flake-parts-lib, ... }:

{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ lib, pkgs, ... }: {
    options.justfiles = lib.mkOption {
      default = { };
      type = lib.types.attrsOf
        (lib.types.submodule ({ config, name, ... }: {
          options = {
            recipes = lib.mkOption {
              default = { };
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  args = lib.mkOption {
                    default = [ ];
                    type = lib.types.listOf (lib.types.either
                      lib.types.str
                      (lib.types.submodule {
                        options = {
                          variadic = lib.mkOption {
                            default = "";
                            type = lib.types.str;
                          };

                          name = lib.mkOption {
                            type = lib.types.nonEmptyStr;
                          };

                          default = lib.mkOption {
                            default = null;
                            type = lib.types.anything;
                          };
                        };
                      }));
                  };

                  doc = lib.mkOption {
                    default = null;
                    type = with lib.types; nullOr nonEmptyStr;
                  };

                  runtimeInputs = lib.mkOption {
                    default = [ ];
                    type = with lib.types; listOf package;
                  };

                  script = lib.mkOption {
                    type = with lib.types; either lines path;
                  };
                };

                config = {
                  runtimeInputs = [ pkgs.coreutils ];
                };
              });
            };

            file = lib.mkOption {
              type = lib.types.package;
            };

            setupScript = lib.mkOption {
              type = lib.types.package;
            };
          };

          config = {
            file =
              let
                argName = arg: if builtins.isString arg then arg else arg.name;

                argDefinition = arg: if builtins.isString arg then arg else argDefinitionSet arg;
                argDefinitionSet = { variadic ? "", name, default ? null }: "${variadic}${name}${lib.optionalString (default != null) ''="${builtins.toString default}"''}";

                argsScript = args: lib.pipe args [
                  (builtins.filter (a: builtins.isString a || !(a ? variadic) || a.variadic == ""))
                  (builtins.map (a: ''
                    readonly arg_${argName a}="$1"
                    shift
                  ''))
                  (builtins.concatStringsSep "")
                ];

                mkJustfile = recipes: lib.pipe recipes [
                  (lib.mapAttrsToList (name: { doc, args, runtimeInputs, script }:
                    let
                      shellScript = pkgs.writeShellApplication {
                        name = "just-recipe-${name}";
                        inherit runtimeInputs;
                        text = ''
                          ${argsScript args}
                          ${if builtins.isPath script then builtins.readFile script else script}
                        '';
                      };
                    in
                    ''
                      ${if (doc != null) then "# ${doc}" else ""}
                      @${name}${builtins.concatStringsSep "" (builtins.map (a: " ${argDefinition a}") args)}:
                          ${lib.getExe shellScript} "$@"
                    ''))

                  (builtins.concatStringsSep "\n")

                  (justfile: ''
                    set positional-arguments

                    @_default:
                        just --list
          
                    ${justfile}
                  '')

                  (pkgs.writeText "${name}.just")
                ];
              in
              mkJustfile config.recipes;

            setupScript = pkgs.writeShellScript "justfile-setup-${name}" ''
              export JUST_JUSTFILE=${config.file}
              export JUST_WORKING_DIRECTORY=$PWD
            '';
          };
        }));
    };
  });

  config = {
    transposition.justfiles = { };
  };
}
