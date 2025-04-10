{ config, lib, ... }:

let
  cfg = config.x.bootstrap.local;
in
{
  options.x.bootstrap.local.enable = lib.mkEnableOption "bootstrapping modules for local VMs";

  config = lib.mkIf cfg.enable {
    x.bootstrap.enable = true;
    x.base.filesystems.virtual.diskDevice = "/dev/vda";
  };
}
