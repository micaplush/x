{ config, lib, ... }:

{
  x.base.sshd.enable = lib.mkIf config.x.server.enable true;
}
