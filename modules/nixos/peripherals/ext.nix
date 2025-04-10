{ config, lib, ... }:

let
  cfg = config.x.peripherals.ext;
in
{
  options.x.peripherals.ext.enable = lib.mkEnableOption "mounting the ext drive.";

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems.zfs = true;

    services.zfs.autoScrub.enable = true;

    # Created using:
    # zpool create -m none -o autoexpand=on ext0 mirror /dev/disk/by-id/usb-Micron_... /dev/disk/by-id/usb-Kingston_...
    # zfs create -o mountpoint=legacy ext0/restic
    fileSystems."/ext/restic" = {
      device = "ext0/restic";
      fsType = "zfs";
    };
  };
}
