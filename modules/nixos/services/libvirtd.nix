{ config, lib, ... }:

let
  cfg = config.x.services.libvirtd;
in
{
  options.x.services.libvirtd.enable = lib.mkEnableOption "libvirtd";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
    };

    x.base.filesystems.persistentDirectories = [
      "/var/lib/libvirt"
    ];

    x.base.restic.exclude = [
      "${config.x.base.filesystems.persistDirectory}/var/lib/libvirt"
    ];
  };
}
