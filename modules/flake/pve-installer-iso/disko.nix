{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
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
}
