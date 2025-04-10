{ config, lib, ... }:

let
  cfg = config.x.services.email;
in
{
  options.x.services.email.enable = lib.mkEnableOption "email services";

  config = lib.mkIf cfg.enable {
    x.services.email = {
      dovecot.enable = true;
      getmail.enable = true;
      getmailtest.enable = true;
      opensmtpd.enable = true;
    };

    x.global.agenix.secrets = {
      upstream-imap-password = { };
      upstream-smtp-password = { };
    };
  };
}
