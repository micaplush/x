{ config, globalConfig, lib, name, pkgs, ... }:

let
  cfg = config.x.base.sshd;
  serviceName = "ssh.${name}";
in
{
  options.x.base.sshd.enable = lib.mkEnableOption "sshd";

  config = lib.mkIf cfg.enable {
    x.base.sshKeySecrets."ssh-host-keys/${name}/ed25519" = {
      publicKeyFile = "secrets/derived/ssh-public-keys/${name}/ed25519";
    };

    x.global.agenix.secretMounts = {
      "ssh-host-keys/${name}/ed25519" = { };
    };

    services.openssh = {
      enable = true;

      allowSFTP = false;
      listenAddresses = lib.singleton {
        addr = "0.0.0.0";
        port = 22;
      };
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };

      hostKeys = [
        {
          path = globalConfig.agenix.secretMounts."ssh-host-keys/${name}/ed25519".path;
          type = "ed25519";
        }
      ];
    };

    x.global.netsrv.services.${serviceName} = {
      accessFromAllHosts = true;
      ports.ssh.port = 22;
      publishDNS = false;
    };
  };
}
