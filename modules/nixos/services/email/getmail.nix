{ config, globalConfig, lib, name, pkgs, ... }:

let
  cfg = config.x.services.email.getmail;

  configMailboxesTuple = account: lib.pipe account.sync.retrieval.mailboxes [
    (builtins.map (m: ''"${m}",''))
    (builtins.concatStringsSep " ")
  ];

  configFile = accountName: account: pkgs.writeText "getmail-config" ''
    [retriever]
    type = SimpleIMAPSSLRetriever
    server = imap.mailbox.org
    port = 993
    username = tbx@mailbox.org
    password_command = ("cat", "upstream-imap-password",)
    mailboxes = (${configMailboxesTuple account})

    [destination]
    type = MDA_external
    path = ${lib.getExe config.x.services.email.dovecot.ldaWrapper}
    arguments = ("-e", "-d", "${accountName}", "-m", "${account.sync.delivery.mailbox}")

    [options]
    delete = false
    read_all = false
  '';

  stateDirectory = accountName: "${config.x.base.filesystems.persistDirectory}/getmail-state/${accountName}";

  activeAccounts = lib.filterAttrs (accountName: account: account.sync.enable) globalConfig.email.accounts;
in
{
  options.x.services.email.getmail.enable = lib.mkEnableOption "getmail";

  config = lib.mkIf cfg.enable {
    x.global.agenix.secretMounts."getmail/upstream-imap-password" = {
      secret = "upstream-imap-password";
    };

    systemd.services = lib.mapAttrs'
      (accountName: account: {
        name = "getmail-${accountName}";
        value =
          let
            sd = stateDirectory accountName;
          in
          {
            path = with pkgs; [ coreutils getmail6 ];

            script = ''
              timeout --signal INT 20m getmail --getmaildir ${sd} --rcfile ${configFile accountName account} --idle ${account.sync.retrieval.idleMailbox}
            '';

            preStart = ''
              ln -sf $CREDENTIALS_DIRECTORY/upstream-imap-password ./upstream-imap-password
            '';

            wantedBy = [ "multi-user.target" ];
            wants = [ "dovecot.service" "network-online.target" ];
            after = [ "dovecot.service" "network-online.target" ];

            serviceConfig = {
              Group = config.users.users.getmail.group;
              User = config.users.users.getmail.name;
              Restart = "always";
              RestartSec = "2s";
              WorkingDirectory = sd;

              LoadCredential = "upstream-imap-password:${globalConfig.agenix.secretMounts."getmail/upstream-imap-password".path}";

              BindPaths = [
                config.x.services.email.dovecot.mailLocation
                sd
              ];
              BindReadOnlyPaths = [
                "/etc"
                "/nix"
                "/run"
              ];
              ExecPaths = [
                "/nix"
              ];
              TemporaryFileSystem = "/:ro,noexec";

              CapabilityBoundingSet = [
                "CAP_SETUID"
                "CAP_SETGID"
                "CAP_CHOWN"
                "CAP_FSETID"
              ];
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              PrivateDevices = true;
              PrivateTmp = true;
              ProcSubset = "pid";
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              RemoveIPC = true;
              RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
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
                "~@raw-io"
                "~@reboot"
                "~@swap"
              ];
            };
          };
      })
      activeAccounts;

    users.users.getmail = {
      isSystemUser = true;
      group = config.users.groups.getmail.name;
      extraGroups = [ config.users.groups.dovecot-lda.name ];
    };

    users.groups.getmail = { };

    systemd.tmpfiles.rules = lib.pipe activeAccounts [
      builtins.attrNames
      (builtins.map (accountName: "d ${stateDirectory accountName} 0700 ${config.users.users.getmail.name} ${config.users.users.getmail.group} -"))
    ];
  };
}
