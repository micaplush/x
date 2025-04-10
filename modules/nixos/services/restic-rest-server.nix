{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.resticRestServer;

  srv = globalConfig.netsrv.services.restic;
  backupSSHKey = "ssh-keys/rsyncnet";
in
{
  options.x.services.resticRestServer.enable = lib.mkEnableOption "the restic REST server.";

  config = lib.mkIf cfg.enable {
    x.base.restic.enable = false;
    x.peripherals.ext.enable = true;

    services.restic.server = {
      enable = true;
      dataDir = "/ext/restic";
      listenAddress = builtins.toString srv.ports.http.port;
      appendOnly = true;
      privateRepos = true;
      extraFlags = [ "--htpasswd-file" globalConfig.agenix.secretMounts."restic/htpasswd".path ];
    };

    x.global.netsrv.services.restic = {
      accessFromAllHosts = true;
      ports.http.port = 6600;
    };

    systemd.services.restic-rest-server = {
      after = [ "ext-restic.mount" ];
      requires = [ "ext-restic.mount" ];
    };

    x.global.agenix.secrets = lib.mkMerge [
      {
        "restic/htpasswd" = {
          generation.template = {
            data.users = builtins.attrValues globalConfig.restic.users;
            content = ''
              {{- range .users -}}
              {{ .name }}:{{ hashBcrypt (readSecret .passwordSecret) 10 }}
              {{ end -}}
            '';
          };
        };
      }

      (lib.pipe globalConfig.restic.users [
        (lib.mapAttrsToList (username: user:
          lib.pipe user.repositories [
            (lib.mapAttrsToList (repoName: repo: {
              ${repo.secrets.password} = {
                generation.random.length = 256;
              };

              ${repo.secrets.url} = {
                generation.template = {
                  data = {
                    inherit repo repoName user;
                    service = globalConfig.netsrv.services.restic;
                  };
                  content = ''rest:http://{{ .user.name }}:{{ fmt "%s" (readSecret .user.passwordSecret) }}@{{ .service.address }}:{{ .service.ports.http.port }}/{{ .user.name }}/{{ .repoName }}'';
                };
              };
            }))
            lib.mkMerge
          ]))
        lib.mkMerge
      ])

      (lib.mapAttrs'
        (username: user: {
          name = user.passwordSecret;
          value = {
            generation.random.charsets.special = false;
          };
        })
        globalConfig.restic.users)
    ];

    x.global.agenix.secretMounts = {
      "restic/htpasswd" = {
        owner = config.users.users.restic.name;
      };

      ${backupSSHKey} = {
        owner = config.users.users.restic.name;
      };
    };

    x.base.sshKeySecrets.${backupSSHKey} = {
      publicKeyFile = "secrets/derived/ssh-public-client-keys/rsyncnet";
    };

    systemd.services.backup = {
      path = with pkgs; [ coreutils openssh rsync ];
      script = ''
        rsync --rsh 'ssh -i ${globalConfig.agenix.secretMounts.${backupSSHKey}.path}' --archive --chown REDACTED:REDACTED --exclude 'fw/*' --verbose /ext/restic REDACTED@REDACTED.rsync.net:
      '';

      serviceConfig = {
        Type = "oneshot";
        User = config.users.users.restic.name;
        Group = config.users.users.restic.group;
      };
    };

    systemd.timers.backup = {
      enable = true;
      timerConfig = {
        Unit = "backup.service";
        OnCalendar = "*-*-* 7:30";
        RandomizedDelaySec = "30min";
      };
      wantedBy = [ "timers.target" ];
    };

    programs.ssh.knownHosts = {
      "REDACTED.rsync.net".publicKey = "ssh-ed25519 AAAAREDACTED";
    };
  };
}
