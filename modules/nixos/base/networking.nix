{ config, globalConfig, lib, name, ... }:

let
  cfg = config.x.base.networking;

  collectFirewallServices = protocol: lib.pipe globalConfig.netsrv.services [
    (lib.filterAttrs (svcName: service: service.host == name))
    (lib.mapAttrsToList (svcName: service: lib.pipe service.ports [
      (lib.filterAttrs (portName: port: port.protocol == protocol))
      (lib.mapAttrsToList (portName: port: port.port))
    ]))
    lib.flatten
  ];
in
{
  options.x.base.networking = {
    macAddressGeneration = lib.mkOption {
      type = lib.types.enum [ "permanent" "random" ];
      default = "random";
    };
  };

  config = {
    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking.useDHCP = false;

    networking.domain = "in.tbx.at";

    networking.networkmanager = {
      enable = true;
      ethernet.macAddress = cfg.macAddressGeneration;
      wifi.macAddress = cfg.macAddressGeneration;
      wifi.scanRandMacAddress = true;

      connectionConfig = {
        "ipv6.ip6-privacy" = 2;
      };

      settings = {
        "global-dns-domain-*".servers = "127.0.0.1";
      };
    };

    x.base.filesystems.persistentDirectories = [
      "/etc/NetworkManager/system-connections"
    ];

    networking.firewall.allowedTCPPorts = lib.mkMerge [
      (collectFirewallServices "tcp")
      [ 8080 ]
    ];

    networking.firewall.allowedUDPPorts = lib.mkMerge [
      (collectFirewallServices "udp")
      [ 8080 ]
    ];
  };
}
