{ lib, ... }:

{
  options.x.server.enable = lib.mkEnableOption "modules for servers";
}
