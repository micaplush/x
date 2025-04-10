{ config, lib, pkgs, ... }:

let
  cfg = config.x.base.sshKeySecrets;
in
{
  options.x.base.sshKeySecrets = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        publicKeyFile = lib.mkOption {
          type = lib.types.str;
        };
      };
    });
  };

  config = {
    x.global.agenix.secrets = lib.mapAttrs'
      (secretName: secret: {
        name = secretName;
        value = {
          generation.script = {
            runtimeInputs = pkgs: with pkgs; [ coreutils openssh ];
            script = ''
              ssh-keygen -t ed25519 -f "$TMP_DIR/key" -C "" -P "" -q
              mkdir -p "$(dirname ${secret.publicKeyFile})"
              mv "$TMP_DIR/key.pub" ${secret.publicKeyFile}
              cat "$TMP_DIR/key"
            '';
          };
        };
      })
      cfg;
  };
}
