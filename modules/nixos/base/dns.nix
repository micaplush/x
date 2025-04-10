{ pkgs, ... }:

# This DNS setup only takes effect when Tailscale doesn't override it with our internal DNS server.

let
  # https://github.com/DigitaleGesellschaft/DNS-Resolver#technical-information--configuration-how-tos
  dotAddresses = [
    "185.95.218.42"
    "185.95.218.43"
  ];
in
{
  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      server = {
        access-control = [ "127.0.0.0/8 allow" ];
        interface = [ "127.0.0.1@53" ];
        log-servfail = true;

        # Don't trust our internal certificates here
        tls-system-cert = false;
        tls-cert-bundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      forward-zone = {
        name = ".";
        forward-tls-upstream = true;
        forward-addr = builtins.map (a: "${a}@853#dns.digitale-gesellschaft.ch") dotAddresses;
      };
    };
  };
}
