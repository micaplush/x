{ config, lib, ... }:

let
  cfg = config.x.services.reverseproxy;
in
{
  options.x.services.reverseproxy.enable = lib.mkEnableOption "reverse proxies for peripherals";

  config = lib.mkIf cfg.enable {
    x.server.caddy.services = {
      openwrt.extraConfig = ''
        reverse_proxy http://192.168.7.1
      '';

      netswitch.extraConfig = ''
        reverse_proxy http://192.168.7.2
      '';

      "console.sg3210".extraConfig = ''
        reverse_proxy http://192.168.7.3
      '';

      "console.crs305".extraConfig = ''
        reverse_proxy http://192.168.7.4
      '';

      scanner.extraConfig = ''
        reverse_proxy http://192.168.9.3
      '';

      shellyplug.extraConfig = ''
        reverse_proxy http://192.168.9.2
      '';
    };
  };
}
