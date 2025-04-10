{ config, pkgs, lib, name, ... }:

let
  cfg = config.x.base.tailscale;
in
{
  options.x.base.tailscale = {
    bootstrapping = lib.mkOption {
      default = false;
      description = "Whether Tailscale is being bootstrapped (i.e. does not have a known IP address yet).";
      type = lib.types.bool;
    };

    domain = lib.mkOption {
      description = "The domain of the Tailnet.";
      readOnly = true;
      type = lib.types.str;
    };

    nodes = lib.mkOption {
      description = "IP addresses of nodes on the Tailnet.";
      readOnly = true;
      type = with lib.types; attrsOf str;
    };
  };

  config = {
    x.base.tailscale = builtins.fromJSON (builtins.readFile ./tailnet.json);

    networking.firewall.allowedUDPPorts = [
      41641
      3478
    ];

    # NOTE: `networking.search` appends its entries at the end of the
    # search list. However, in this case it's preferrable to have the
    # Tailnet domain at the start since it's probably gonna be
    # requested often. Hence why this method is used.
    networking.resolvconf.extraConfig = ''
      search_domains='${config.x.base.tailscale.domain}'
    '';

    services.tailscale.enable = true;

    # HACK: Work around the fact that tailscaled.service is up before
    # the Tailscale IP can be bound to (https://github.com/tailscale/tailscale/issues/11504).
    systemd.services.tailscale-up = {
      enable = !cfg.bootstrapping;

      serviceConfig = {
        Type = "oneshot";
      };

      path = [ pkgs.iproute2 ];
      script = ''
        while ! ip addr show dev tailscale0 | grep -q ${if cfg.bootstrapping then "dummy" else cfg.nodes.${name}}; do
          sleep 1
        done
      '';

      requires = [ "tailscaled.service" ];
      after = [ "tailscaled.service" ];
    };

    systemd.targets.network-online = {
      after = [ "tailscale-up.service" ];
      wants = [ "tailscale-up.service" ];
    };

    x.base.filesystems.persistentDirectories = [
      "/var/lib/tailscale"
    ];
  };
}
