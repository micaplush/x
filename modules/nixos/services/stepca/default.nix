{ config, globalConfig, lib, ... }:

let
  cfg = config.x.services.stepca;
  srv = globalConfig.netsrv.services.ca;
in
{
  options.x.services.stepca.enable = lib.mkEnableOption "Step CA.";

  config = lib.mkIf cfg.enable {
    services.step-ca = {
      enable = true;
      intermediatePasswordFile = globalConfig.agenix.secretMounts.intermediate-ca-key-password.path;
      address = srv.address;
      port = srv.ports.https.port;

      settings = {
        authority = {
          provisioners = [
            {
              encryptedKey = "REDACTED";
              key = {
                alg = "ES256";
                crv = "P-256";
                kid = "REDACTED";
                kty = "EC";
                use = "sig";
                x = "REDACTED";
                y = "REDACTED";
              };
              name = "ca@in.tbx.at";
              type = "JWK";
            }
            {
              name = "acme";
              type = "ACME";
              caaIdentities = [ "ca.in.tbx.at" ];
              challenges = [
                "http-01"
              ];
            }
          ];
        };
        crt = ./intermediate_ca.crt;
        db = {
          badgerFileLoadingMode = "";
          dataSource = "/var/lib/step-ca/db";
          type = "badgerv2";
        };
        dnsNames = [ "ca.in.tbx.at" ];
        federatedRoots = null;
        insecureAddress = "";
        key = globalConfig.agenix.secretMounts.intermediate-ca-key.path;
        logger.format = "text";
        root = ./root_ca.crt;
        tls = {
          cipherSuites = [
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
          ];
          maxVersion = 1.3;
          minVersion = 1.2;
          renegotiation = false;
        };
      };
    };

    x.global.netsrv.services.ca = {
      accessFromAllHosts = true;
      ports.https.port = 443;
    };

    x.global.agenix.secrets = {
      intermediate-ca-key = { };
      intermediate-ca-key-password = { };
    };

    x.global.agenix.secretMounts = {
      intermediate-ca-key = {
        owner = config.users.users.step-ca.name;
        group = config.users.groups.step-ca.name;
      };

      intermediate-ca-key-password = {
        owner = config.users.users.step-ca.name;
        group = config.users.groups.step-ca.name;
      };
    };

    x.base.filesystems.persistentDirectories = [ "/var/lib/private/step-ca" ];

    systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];
  };
}
