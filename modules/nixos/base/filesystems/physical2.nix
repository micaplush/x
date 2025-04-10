{ config, deps, lib, pkgs, ... }:

let
  cfg = config.x.base.filesystems;
  inherit (deps) disko;
in
{
  imports = [
    disko.nixosModules.disko
  ];

  options.x.base.filesystems.physical2 = lib.mkOption {
    default = null;
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        diskDevice = lib.mkOption {
          type = lib.types.str;
        };
      };
    });
  };

  config = lib.mkIf (cfg.physical2 != null) {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = cfg.physical2.diskDevice;
          content = {
            type = "gpt";
            partitions = {
              mbr = {
                priority = 0;
                size = "1M";
                type = "EF02";
              };

              esp = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };

              crypt-meta = {
                size = "500M";
                content = {
                  type = "luks";
                  name = "crypt-meta";
                  passwordFile = "/tmp/luks-passphrase";
                  settings = {
                    allowDiscards = true;
                    keyFile = "/dev/disk/by-partlabel/key-meta";
                  };
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    extraArgs = [ "-L" "meta" ];
                  };
                };
              };

              crypt-primary = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypt-primary";
                  passwordFile = "/tmp/luks-passphrase";
                  settings = {
                    allowDiscards = true;
                    keyFile = "/dev/disk/by-partlabel/key-primary";
                  };
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-L" "primary" ];
                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                      };
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
    };

    fileSystems."/persist".neededForBoot = true;

    boot.initrd.luks.reusePassphrases = true;

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

    environment.persistence.${cfg.persistDirectory}.directories = cfg.persistentDirectories;
  };
}
