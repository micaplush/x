{ config, lib, ... }:

let
  cfg = config.x.bootstrap.hetzner;
in
{
  options.x.bootstrap.hetzner.enable = lib.mkEnableOption "bootstrapping modules for VMs on Hetzner";

  config = lib.mkIf cfg.enable {
    x.bootstrap.enable = true;
    x.base.filesystems.virtual.diskDevice = "/dev/sda";
    x.base.networking.macAddressGeneration = "permanent";
  };
}
