{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.email.dovecot;

  nixosConfig = config.services.dovecot2;

  mailLocation = "${config.x.base.filesystems.persistDirectory}/dovecot-mail";
in
{
  options.x.services.email.dovecot = {
    enable = lib.mkEnableOption "Dovecot";

    ldaWrapper = lib.mkOption {
      readOnly = true;
      type = lib.types.package;
    };

    mailLocation = lib.mkOption {
      readOnly = true;
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    x.services.email.dovecot = {
      inherit mailLocation;

      ldaWrapper = pkgs.writeShellScriptBin "dovecot-lda" ''
        /run/wrappers/bin/sudo -u ${config.services.dovecot2.user} -g ${config.services.dovecot2.group} ${pkgs.dovecot}/libexec/dovecot/dovecot-lda "$@"
      '';
    };

    x.global.agenix.secrets = lib.mkMerge [
      {
        "dovecot/passdb" = {
          generation.template = {
            data.accounts = lib.pipe globalConfig.email.accounts [
              (lib.filterAttrs (address: account: account.permissions.receive))
              (lib.mapAttrsToList (address: account: {
                inherit address;
                passwordSecret = account.secrets.imap;
              }))
            ];
            content = ''
              {{- range .accounts -}}
              {{ .address }}:{{ hashBcrypt (readSecret .passwordSecret) 10 }}::::::
              {{ end -}}
            '';
          };
        };
      }

      (lib.pipe globalConfig.email.accounts [
        (lib.filterAttrs (address: account: account.permissions.receive))
        (lib.mapAttrs' (address: account: {
          name = account.secrets.imap;
          value = {
            generation.random = {
              charsets.special = account.secrets.passwordsContainSpecialChars;
              length = account.secrets.passwordLength;
            };
          };
        }))
      ])
    ];

    x.global.agenix.secretMounts."dovecot/passdb" = {
      owner = nixosConfig.user;
      group = nixosConfig.group;
    };

    services.dovecot2 = {
      enable = true;
      enableLmtp = true;
      enablePAM = false;
      enablePop3 = false;

      sslServerCert = "${config.x.server.acme.certs.imap.directory}/cert.pem";
      sslServerKey = "${config.x.server.acme.certs.imap.directory}/key.pem";

      mailLocation = "maildir:${mailLocation}/%u";
      mailboxes = {
        Drafts = { specialUse = "Drafts"; auto = "create"; };
        Sent = { specialUse = "Sent"; auto = "create"; };
        Spam = { specialUse = "Junk"; auto = "subscribe"; };
        Trash = { specialUse = "Trash"; auto = "create"; };
      };

      extraConfig = ''
        listen = ${globalConfig.netsrv.services.imap.address}
        ssl = yes

        first_valid_uid = ${builtins.toString config.users.users.${nixosConfig.user}.uid}

        passdb {
          driver = passwd-file
          args = ${globalConfig.agenix.secretMounts."dovecot/passdb".path}
        }

        userdb {
          driver = passwd-file
          args = ${globalConfig.agenix.secretMounts."dovecot/passdb".path}
          default_fields = uid=${nixosConfig.user} gid=${nixosConfig.group} home=${mailLocation}/%u
        }
      '';
    };

    system.activationScripts.dovecot-mail-dir.text = ''
      mkdir -p ${mailLocation}
      chmod u=rwx,go= ${mailLocation}
      chown ${nixosConfig.user}:${nixosConfig.group} ${mailLocation}
    '';

    x.global.netsrv.services.imap.ports = {
      imap.port = 143;
      imaps.port = 993;
    };

    x.server.acme.certs.imap.options.postRun = ''
      systemctl restart dovecot2.service
    '';

    systemd.services.dovecot2 = {
      preStart = lib.mkBefore ''
        ln -s $CREDENTIALS_DIRECTORY/cert.pem .
        ln -s $CREDENTIALS_DIRECTORY/key.pem .
      '';

      after = [ "tailscale-up.service" ];

      requires = [
        "acme-finished-${config.x.server.acme.certs.imap.commonName}.target"
        "tailscale-up.service"
      ];

      serviceConfig = {
        LoadCredential =
          let
            certDir = config.x.server.acme.certs.imap.directory;
          in
          [
            "cert.pem:${certDir}/cert.pem"
            "key.pem:${certDir}/key.pem"
          ];
        WorkingDirectory = "/run/dovecot2";
      };
    };

    users.groups.dovecot-lda = { };

    security.sudo.extraRules = lib.singleton {
      groups = [ config.users.groups.dovecot-lda.name ];
      runAs = "${config.services.dovecot2.user}:${config.services.dovecot2.group}";
      commands = lib.singleton {
        command = "${pkgs.dovecot}/libexec/dovecot/dovecot-lda";
        options = [ "NOPASSWD" ];
      };
    };
  };
}
