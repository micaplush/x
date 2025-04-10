{ config, lib, pkgs, ... }:

let
  cfg = config.x.base.filesystems;
in
{
  options.x.base.filesystems.physical = lib.mkOption {
    default = null;
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        swapfileResumeOffset = lib.mkOption {
          type = lib.types.int;
        };
      };
    });
  };

  config = lib.mkIf (cfg.physical != null) {
    boot.supportedFilesystems = [ "btrfs" ];

    boot.resumeDevice = "/dev/disk/by-label/primary";
    boot.kernelParams = [ "resume_offset=${builtins.toString cfg.physical.swapfileResumeOffset}" ];

    boot.initrd.postDeviceCommands = ''
      mkdir /meta
      mount -t ext4 /dev/disk/by-label/meta /meta

      if [ -e /meta/clear-for-rollback ]; then
        echo "Clear for root filesystem rollback"
        rm /meta/clear-for-rollback

        mkdir /primary
        mount -t btrfs /dev/disk/by-label/primary /primary

        echo "Subvolumes at boot:"
        btrfs subvolume list -o /primary/root

        echo "Deleting weird subvolumes that are already there for some reason..."
        btrfs subvolume delete /primary/root/srv
        btrfs subvolume delete /primary/root/tmp
        btrfs subvolume delete /primary/root/var/lib/machines
        btrfs subvolume delete /primary/root/var/lib/portables
        btrfs subvolume delete /primary/root/var/tmp

        echo "Rolling back root subvolume..."
        btrfs subvolume delete /primary/root && btrfs subvolume snapshot /primary/root-blank /primary/root || { echo "Contents of root subvolume:"; ls -a /primary/root; }

        umount /primary
      else
        echo "NOT clear for root filesystem rollback"
      fi

      umount /meta
    '';

    boot.initrd.luks.reusePassphrases = true;
    boot.initrd.luks.devices = {
      meta = {
        device = "/dev/disk/by-label/crypt-meta";
        keyFile = "/dev/disk/by-partlabel/key-meta";
        fallbackToPassword = true;
      };

      primary = {
        device = "/dev/disk/by-label/crypt-primary";
        keyFile = "/dev/disk/by-partlabel/key-primary";
        fallbackToPassword = true;
      };
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/primary";
        fsType = "btrfs";
        options = [ "subvol=root" ];
      };

      "/nix" = {
        device = "/dev/disk/by-label/primary";
        fsType = "btrfs";
        options = [ "subvol=nix" ];
      };

      ${cfg.persistDirectory} = {
        device = "/dev/disk/by-label/primary";
        fsType = "btrfs";
        options = [ "subvol=persist" ];
        neededForBoot = true;
      };

      "/var/lib/swap" = {
        device = "/dev/disk/by-label/primary";
        fsType = "btrfs";
        options = [ "subvol=swap" ];
        neededForBoot = true;
      };

      "/snapshots" = {
        device = "/dev/disk/by-label/primary";
        fsType = "btrfs";
        options = [ "subvol=snapshots" ];
      };

      "/boot" = {
        device = "/dev/disk/by-label/boot";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };

    swapDevices = [
      { device = "/var/lib/swap/swapfile"; }
    ];

    systemd.services.set-rollback-flag = {
      enable = true;
      path = with pkgs; [ coreutils util-linux ];
      script = ''
        mkdir -p /tmp/fs-meta
        mount -t ext4 /dev/disk/by-label/meta /tmp/fs-meta
        touch /tmp/fs-meta/clear-for-rollback
        umount /tmp/fs-meta
      '';

      serviceConfig.Type = "oneshot";
      unitConfig = {
        DefaultDependencies = false; # removes Conflicts= with shutdown.target
        RemainAfterExit = true;
      };

      before = [ "shutdown.target" ];
      conflicts = [ ];
      wantedBy = [ "shutdown.target" ];
    };

    environment.persistence.${cfg.persistDirectory}.directories = cfg.persistentDirectories;
  };
}
