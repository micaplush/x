{ config, lib, self', ... }:

let
  cfg = config.x.services.website;
in
{
  options.x.services.website.enable = lib.mkEnableOption "netsrv to redirect to mica.lgbt.";

  config = lib.mkIf cfg.enable {
    x.server.caddy.services.website.extraConfig = ''
      redir https://mica.lgbt
    '';
  };
}
