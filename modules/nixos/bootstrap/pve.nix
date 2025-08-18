{ config, lib, ... }:

let
  cfg = config.x.bootstrap.pve;
in
{
  options.x.bootstrap.pve.enable = lib.mkEnableOption "bootstrapping modules for VMs on Foxmox";

  config = lib.mkIf cfg.enable {
    x.bootstrap.enable = true;
    x.base.filesystems.virtual.diskDevice = "/dev/sda";
  };
}
