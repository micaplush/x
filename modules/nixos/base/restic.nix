{ config, globalConfig, lib, name, pkgs, ... }:

let
  cfg = config.x.base.restic;

  repo = globalConfig.restic.users.${name}.repositories.persist;

  secretMounts = {
    repoPassword = globalConfig.agenix.secretMounts.${repo.secrets.password};
    repoURL = globalConfig.agenix.secretMounts.${repo.secrets.url};
  };

  p = config.x.base.filesystems.persistDirectory;
  cacheDir = "${p}/restic-cache";

  excludePatterns = cfg.exclude ++ [
    cacheDir
    "${p}/var/lib/tor"
    "${p}/var/log"
  ];

  createResticBackup = pkgs.writeShellApplication {
    name = "create-restic-backup";
    runtimeInputs = [ pkgs.restic ];
    text = ''
      tag="$1"
      readonly tag

      all_proxy="" http_proxy="" ${lib.getExe' pkgs.restic "restic"} backup \
          --cache-dir ${lib.escapeShellArg cacheDir} \
          --exclude-caches \
          ${lib.concatMapStringsSep "\n" (x: "--exclude ${lib.escapeShellArg x} \\") excludePatterns}
          --one-file-system \
          --password-file ${lib.escapeShellArg secretMounts.repoPassword.path} \
          --repository-file ${lib.escapeShellArg secretMounts.repoURL.path} \
          --tag "$tag" \
          "''${@:2}" \
          ${lib.escapeShellArg p}
    '';
  };
in
{
  options.x.base.restic = {
    enable = lib.mkOption {
      default = true;
      type = lib.types.bool;
    };

    enableAutomaticBackups = lib.mkOption {
      default = true;
      description = "Enable automatic backups to the network-wide restic REST server.";
      type = lib.types.bool;
    };

    exclude = lib.mkOption {
      default = [ ];
      description = "File patterns to exclude in restic backups.";
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    x.global.restic.users.${name}.repositories.persist = { };

    x.global.agenix.secretMounts = {
      ${repo.secrets.password} = { };
      ${repo.secrets.url} = { };
    };

    environment.systemPackages = [
      pkgs.restic
      createResticBackup
    ];

    systemd.services.daily-restic-backup = {
      serviceConfig = {
        Type = "oneshot";

        TemporaryFileSystem = "/:ro,noexec";
        BindReadOnlyPaths = [
          "/etc/passwd"
          "/nix"
          "/run/agenix"
          "/run/current-system"
          "/usr/bin/env"
          p
        ];
        BindPaths = [
          "${p}/restic-cache"
        ];
        ExecPaths = [
          "/nix"
          "/usr/bin/env"
        ];
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        PrivateDevices = true;
        PrivateIPC = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        CapabilityBoundingSet = [
          "cap_dac_override"
          "cap_dac_read_search"
        ];
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectProc = "ptraceable";
        SocketBindDeny = "any";
        IPAddressAllow = globalConfig.netsrv.services.restic.address;
        IPAddressDeny = "any";
        RestrictAddressFamilies = [ "AF_INET" ];
        RestrictRealtime = true;
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
          "~@swap"
        ];
      };
      path = with pkgs; [ bash hostname restic ];
      script = ''
        ${createResticBackup}/bin/create-restic-backup daily
      '';
    };

    systemd.timers.daily-restic-backup = {
      enable = cfg.enableAutomaticBackups;

      timerConfig = {
        Unit = "daily-restic-backup.service";
        OnCalendar = "*-*-* 16:30";
        RandomizedDelaySec = "30min";
        Persistent = true;
      };

      wantedBy = [ "timers.target" ];
    };
  };
}
