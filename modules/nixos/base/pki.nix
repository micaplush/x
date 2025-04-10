{ config, globalConfig, lib, ... }:

{
  security.pki.certificates = lib.singleton ''
    tbx.at Internal
    ===============
    Not dangerous but I'm still not publishing it (PEM-encoded CA cert)
  '';

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "acme@tbx.at";
      server = "https://${globalConfig.netsrv.services.ca.fqdn}/acme/acme/directory";
    };
  };
}
