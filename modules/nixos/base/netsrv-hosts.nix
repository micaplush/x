{ config, ... }:

{
  x.global.netsrv.hosts = config.x.base.tailscale.nodes;
}
