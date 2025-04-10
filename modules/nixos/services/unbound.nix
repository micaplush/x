{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.unbound;

  service = globalConfig.netsrv.services.dns;

  hostRecords = lib.pipe globalConfig.netsrv.hosts [
    (lib.mapAttrsToList (hostname: address: "${hostname} IN A ${address}"))
    (builtins.concatStringsSep "\n")
  ];

  serviceRecords = lib.pipe globalConfig.netsrv.services [
    (lib.filterAttrs (srvName: srv: srv.publishDNS))
    (lib.mapAttrsToList (srvName: srv: "${srvName} IN A ${srv.address}"))
    (builtins.concatStringsSep "\n")
  ];

  # https://github.com/DigitaleGesellschaft/DNS-Resolver#technical-information--configuration-how-tos
  dotAddresses = [
    "185.95.218.42"
    "185.95.218.43"
  ];
in
{
  options.x.services.unbound.enable = lib.mkEnableOption "Unbound";

  config = lib.mkIf cfg.enable {
    x.global.netsrv.services.dns = {
      accessFromAllHosts = true;
      ports.dns = {
        port = 53;
        protocol = "udp";
      };
    };

    services.unbound = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        server = {
          access-control = [ "100.0.0.0/8 allow" ];
          interface = [ "${service.address}@${builtins.toString service.ports.dns.port}" ];
          log-servfail = true;

          # Don't trust our internal certificates here
          tls-system-cert = false;
          tls-cert-bundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        auth-zone = {
          name = "in.tbx.at";
          zonefile = builtins.toFile "zone-in.tbx.at" ''
            $ORIGIN in.tbx.at.
            $TTL 60
            in.tbx.at.    IN  SOA   dns.in.tbx.at. system.tbx.at. ( 1 7200 3600 1209600 3600 )
            in.tbx.at.    IN  NS    dns

            ${hostRecords}

            ${serviceRecords}
          '';
        };
        forward-zone = {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = builtins.map (a: "${a}@853#dns.digitale-gesellschaft.ch") dotAddresses;
        };
      };
    };

    systemd.services.unbound = {
      after = [ "tailscale-up.service" ];
      requires = [ "tailscale-up.service" ];
    };
  };
}
