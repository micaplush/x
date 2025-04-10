{ config, deps, lib, pkgs, ... }:

let
  cfg = config.x.base.filesystems;
  inherit (deps) disko;
in
{
  imports = [
    disko.nixosModules.disko
  ];

  options.x.base.filesystems.virtual = lib.mkOption {
    default = null;
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        diskDevice = lib.mkOption {
          type = lib.types.str;
        };

        diskSize = lib.mkOption {
          type = lib.types.str;
          default = "40G";
        };
      };
    });
  };

  config = lib.mkIf (cfg.virtual != null) {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = cfg.virtual.diskDevice;
          imageSize = cfg.virtual.diskSize;
          content = {
            type = "gpt";
            partitions = {
              mbr = {
                priority = 0;
                size = "1M";
                type = "EF02";
              };
              boot = {
                priority = 1;
                size = "500M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              meta = {
                size = "100M";
                content = {
                  type = "filesystem";
                  format = "ext4";
                };
              };
              primary = {
                size = "100%";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # Override existing partition
                  # Subvolumes must set a mountpoint in order to be mounted,
                  # unless their parent is mounted
                  subvolumes = {
                    # Subvolume name is different from mountpoint
                    "/root" = {
                      mountpoint = "/";
                    };
                    # Parent is not mounted so the mountpoint must be set
                    "/nix" = {
                      mountOptions = [ "noatime" ];
                      mountpoint = "/nix";
                    };
                    "/persist" = {
                      mountpoint = "/persist";
                    };
                    "/snapshots" = {
                      mountpoint = "/snapshots";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

    fileSystems."/persist".neededForBoot = true;

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
        btrfs subvolume delete /primary/root && btrfs subvolume create /primary/root || { echo "Contents of root subvolume:"; ls -a /primary/root; }

        umount /primary
      else
        echo "NOT clear for root filesystem rollback"
      fi

      umount /meta
    '';

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
  };
}
