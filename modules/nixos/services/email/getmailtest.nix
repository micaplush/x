{ config, globalConfig, pkgs, lib, ... }:

let
  cfg = config.x.services.email.getmailtest;

  magicText = "stan Off The Hook;";

  localEmail = "getmailtest@systems.tbx.at";
  upstreamEmail = "postmaster+retrievaltest@tbx.at";

  testMessage = builtins.toFile "getmailtest-message" ''
    From: "Automated Retrieval Test" <${upstreamEmail}>
    To: "Automated Retrieval Test" <${upstreamEmail}>
    Date: %header_date%
    Subject: Automated Retrieval Test

    If you're reading this and you're not me, then this email has reached you by accident. Sorry!

    Please reply so that I can fix my terrible scripts.

    Magic text:
    ${magicText} %date%
  '';
in
{
  options.x.services.email.getmailtest.enable = lib.mkEnableOption "automated tests for getmail";

  config = lib.mkIf cfg.enable {
    x.global.agenix.secrets = {
      "getmailtest/imap-netrc" = {
        generation.template = {
          data = {
            inherit localEmail;
            imapServiceFQDN = globalConfig.netsrv.services.imap.fqdn;
            passwordSecret = globalConfig.email.accounts.${localEmail}.secrets.imap;
          };
          content = ''
            machine {{ .imapServiceFQDN }}
            login {{ .localEmail }}
            password {{ fmt "%s" (readSecret .passwordSecret) }}
          '';
        };
      };

      "getmailtest/smtp-netrc" = {
        generation.template.content = ''
          machine smtp.mailbox.org
          login tbx@mailbox.org
          password {{ fmt "%s" (readSecret "upstream-smtp-password") }}
        '';
      };
    };

    x.global.agenix.secretMounts = {
      "getmailtest/imap-netrc" = { };
      "getmailtest/smtp-netrc" = { };
    };

    x.global.email.accounts.${localEmail} = {
      permissions.receive = true;
      sync = {
        enable = true;
        retrieval.idleMailbox = "RetrievalTest";
        delivery.mailbox = "INBOX";
      };
    };

    systemd.services.getmailtest = {
      path = with pkgs; [ coreutils curl ];
      script = ''
        set -x

        check_date=$(date +%s)

        curl smtps://smtp.mailbox.org \
          --netrc-file $CREDENTIALS_DIRECTORY/smtp-netrc \
          --mail-from ${upstreamEmail} \
          --mail-rcpt ${upstreamEmail} \
          --upload-file <(sed "s/%date%/$check_date/;s/%header_date/$(date --rfc-2822)/" ${testMessage})

        tries=0
        while sleep 1; do
          tries=$((tries+1))
          if [[ "$tries" -gt 60 ]]; then
            echo "Timed out waiting for email to appear"
            exit 1
          fi

          if ! curl "imaps://imap.in.tbx.at/INBOX;MAILINDEX=1" \
            --netrc-file $CREDENTIALS_DIRECTORY/imap-netrc \
            --output latest-email
          then
            continue
          fi

          curl "imaps://imap.in.tbx.at/INBOX;MAILINDEX=1" \
            --netrc-file $CREDENTIALS_DIRECTORY/imap-netrc \
            -X "STORE 1 +FLAGS (\\Deleted)"

          curl imaps://imap.in.tbx.at/INBOX \
            --netrc-file $CREDENTIALS_DIRECTORY/imap-netrc \
            -X EXPUNGE

          if grep -q ${lib.escapeShellArg magicText}" $check_date" latest-email; then
            exit
          fi
        done
      '';

      wants = [ "getmail-${localEmail}.service" ];

      serviceConfig = {
        Type = "oneshot";

        DynamicUser = true;
        LoadCredential = [
          "imap-netrc:${globalConfig.agenix.secretMounts."getmailtest/imap-netrc".path}"
          "smtp-netrc:${globalConfig.agenix.secretMounts."getmailtest/smtp-netrc".path}"
        ];

        RuntimeDirectory = "getmailtest";
        WorkingDirectory = "/run/getmailtest";

        BindPaths = [
          "/run/getmailtest"
        ];
        BindReadOnlyPaths = [
          "/nix"
        ];
        ExecPaths = [
          "/nix"
        ];
        TemporaryFileSystem = "/:ro,noexec";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectProc = "ptraceable";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_INET" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SocketBindDeny = "any";
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "~@clock"
          "~@cpu-emulation"
          "~@debug"
          "~@module"
          "~@mount"
          "~@obsolete"
          "~@privileged"
          "~@raw-io"
          "~@reboot"
          "~@resources"
          "~@swap"
        ];
        UMask = "0077";
      };
    };

    systemd.timers.getmailtest = {
      timerConfig.OnCalendar = "00/3:00"; # every 3 hours
      wantedBy = [ "timers.target" ];
    };
  };
}
