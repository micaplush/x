{ config, lib, ... }:

let
  cfg = config.x.services.res;
in
{
  options.x.services.res.enable = lib.mkEnableOption "the resource server";

  config = lib.mkIf cfg.enable {
    x.server.caddy.services.res.extraConfig = ''
      file_server {
        root ${./content}
        browse
      }

      header {
        -ETag
        -Last-Modified
      }
    '';
  };
}
