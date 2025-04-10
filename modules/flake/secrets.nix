{ flake-parts-lib, lib, self, ... }:

{
  options = {
    secretsAdminPublicKeys = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
    };

    perSystem = flake-parts-lib.mkPerSystemOption ({ lib, pkgs, self', ... }: {
      options = {
        secretsGenerationData = lib.mkOption {
          type = lib.types.attrs;
          readOnly = true;
        };

        secretsGenerationConfig = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
        };
      };

      config = {
        secretsGenerationData =
          let
            globalConfig = self.globalConfig.config.x.global.agenix;

            mapSecret = secretName: secret:
              if secret.generation.script == null
              then secret
              else
                lib.recursiveUpdate secret {
                  generation.script = {
                    runtimeInputs = secret.generation.script.runtimeInputs pkgs;
                    program = secret.generation.script.program pkgs;
                  };
                };
          in
          globalConfig // {
            secrets = lib.mapAttrs mapSecret globalConfig.secrets;
          };

        secretsGenerationConfig = lib.pipe self'.secretsGenerationData [
          builtins.toJSON
          (pkgs.writeText "secrets-config.json")
        ];
      };
    });
  };

  config = {
    flake = {
      secretsAdminPublicKeys = [
        "ageREDACTED"
      ];
    };

    transposition = {
      secretsGenerationData = { };
      secretsGenerationConfig = { };
    };
  };
}
