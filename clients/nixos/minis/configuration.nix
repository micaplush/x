{ lib, name, ... }:

{
  networking.hostId = "redacted";

  x.base.agenix.keys = lib.singleton "key_2024-05-31";
  x.base.filesystems.physical.swapfileResumeOffset = 533760;

  x.global.agenix.publicKeys.${name} = [
    "ageREDACTED"
  ];

  x.server.enable = true;

  x.services = {
    authelia.enable = true;
    dir.enable = true;
    email.enable = true;
    forgejo.enable = true;
    freeradius.enable = true;
    grafana.enable = true;
    libvirtd.enable = true;
    ntfy.enable = true;
    paperless.enable = true;
    prometheus.enable = true;
    radicale.enable = true;
    res.enable = true;
    reverseproxy.enable = true;
    unbound.enable = true;
    website.enable = true;
  };

  x.peripherals = {
    labelprinter.enable = true;
  };

  system.stateVersion = "23.11";
}
