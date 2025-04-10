{ config, globalConfig, lib, ... }:

let
  inherit (globalConfig.email) localDomains outboundAuthorizedUsers;

  cfg = config.x.services.email.opensmtpd;

  smtpdUser = config.users.users.smtpd.name;
  smtpdGroup = config.users.users.smtpd.group;

  addresses = lib.pipe globalConfig.email.accounts [
    (lib.filterAttrs (accountName: account: account.permissions.receive))
    (lib.mapAttrs (accountName: account: account.aliases))
  ];

  virtualUsers = lib.pipe addresses [
    (lib.mapAttrsToList
      (primary: aliases: [
        { ${primary} = "smtpd"; }
        (lib.pipe aliases [
          (builtins.filter (alias:
            (builtins.any (d: lib.hasSuffix d alias) localDomains) &&
            alias != primary))
          (builtins.map (alias: { ${alias} = primary; }))
        ])
      ]))
    lib.flatten
    lib.mergeAttrsList
  ];

  localDomainsTable = builtins.toFile
    "smtpd-local-domains"
    (builtins.concatStringsSep "\n" localDomains);

  outboundAuthTable = builtins.toFile
    "smtpd-outbound-auth"
    (builtins.concatStringsSep "\n" outboundAuthorizedUsers);

  virtualUsersTable = lib.pipe virtualUsers [
    (lib.mapAttrsToList (k: v: "${k}: ${v}"))
    (builtins.concatStringsSep "\n")
    (builtins.toFile "smtpd-virtual-users")
  ];
in
{
  options.x.services.email.opensmtpd.enable = lib.mkEnableOption "OpenSMTPD";

  config = lib.mkIf cfg.enable {
    x.global.agenix.secrets = lib.mkMerge [
      {
        "opensmtpd/relays" = {
          generation.template.content = ''
            mbo	tbx@mailbox.org:{{ fmt "%s" (readSecret "upstream-smtp-password" )}}
          '';
        };

        "opensmtpd/users" = {
          generation.template = {
            data.accounts = lib.pipe globalConfig.email.accounts [
              (lib.filterAttrs (address: account: account.permissions.send))
              (lib.mapAttrsToList (address: account: {
                inherit address;
                passwordSecret = account.secrets.smtp;
              }))
            ];
            content = ''
              {{- range .accounts -}}
              {{ .address }}	{{ hashBcrypt (readSecret .passwordSecret) 10 }}
              {{ end -}}
            '';
          };
        };
      }

      (lib.pipe globalConfig.email.accounts [
        (lib.filterAttrs (address: account: account.permissions.send))
        (lib.mapAttrs' (address: account: {
          name = account.secrets.smtp;
          value = {
            generation.random = {
              charsets.special = account.secrets.passwordsContainSpecialChars;
              length = account.secrets.passwordLength;
            };
          };
        }))
      ])
    ];

    x.global.agenix.secretMounts = {
      "opensmtpd/relays" = {
        owner = smtpdUser;
        group = smtpdGroup;
      };

      "opensmtpd/users" = {
        owner = smtpdUser;
        group = smtpdGroup;
      };
    };

    services.opensmtpd = {
      enable = true;
      setSendmail = false;
      serverConfiguration = ''
        table relays file:${globalConfig.agenix.secretMounts."opensmtpd/relays".path}
        table users file:${globalConfig.agenix.secretMounts."opensmtpd/users".path}

        table local_domains file:${localDomainsTable}
        table outbound_auth file:${outboundAuthTable}
        table virtual_users file:${virtualUsersTable}

        pki "internal" cert "cert.pem"
        pki "internal" key "key.pem"
        pki "internal" dhe auto

        listen on 0.0.0.0 \
          port ${builtins.toString globalConfig.netsrv.services.smtp.ports.smtps.port} \
          smtps \
          pki "internal" \
          auth <users>

        listen on 0.0.0.0 \
          port ${builtins.toString globalConfig.netsrv.services.smtp.ports.smtp.port} \
          tls \
          pki "internal" \
          auth <users>

        action "local_mail" lmtp "/run/dovecot2/lmtp" rcpt-to virtual <virtual_users>
        action "outbound" relay host smtps://mbo@smtp.mailbox.org \
          auth <relays>

        match from auth for domain <local_domains> \
          action "local_mail"

        match from auth <outbound_auth> for any \
          action "outbound"
      '';
    };

    systemd.services.opensmtpd = {
      preStart = ''
        ln -s $CREDENTIALS_DIRECTORY/cert.pem .
        ln -s $CREDENTIALS_DIRECTORY/key.pem .
      '';

      requires = [ "acme-finished-${config.x.server.acme.certs.smtp.commonName}.target" ];

      serviceConfig = {
        LoadCredential =
          let
            certDir = config.x.server.acme.certs.smtp.directory;
          in
          [
            "cert.pem:${certDir}/cert.pem"
            "key.pem:${certDir}/key.pem"
          ];
        RuntimeDirectory = "opensmtpd";
        WorkingDirectory = "/run/opensmtpd";
      };
    };

    x.global.netsrv.services.smtp.ports = {
      smtp.port = 25;
      smtps.port = 465;
    };

    x.server.acme.certs.smtp.options.postRun = ''
      systemctl restart opensmtpd.service
    '';
  };
}
