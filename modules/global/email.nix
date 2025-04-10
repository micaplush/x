{ lib, localEval, ... }:

{
  options.x.global.email = {
    accounts = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
        options = {
          aliases = lib.mkOption {
            default = [ ];
            type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
          };

          permissions = {
            send = lib.mkOption {
              default = false;
              type = lib.types.bool;
            };

            receive = lib.mkOption {
              default = false;
              type = lib.types.bool;
            };
          };

          secrets = {
            imap = lib.mkOption {
              readOnly = localEval;
              type = lib.types.str;
            };

            smtp = lib.mkOption {
              readOnly = localEval;
              type = lib.types.str;
            };

            passwordLength = lib.mkOption {
              default = 64;
              type = lib.types.int;
            };

            passwordsContainSpecialChars = lib.mkOption {
              default = true;
              type = lib.types.bool;
            };
          };

          sync = {
            enable = lib.mkEnableOption "one-way email sync from the upstream mail provider";

            retrieval = {
              idleMailbox = lib.mkOption {
                type = lib.types.str;
              };

              mailboxes = lib.mkOption {
                default = [ config.sync.retrieval.idleMailbox ];
                type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
              };
            };

            delivery = {
              mailbox = lib.mkOption {
                default = "%(mailbox)";
                type = lib.types.str;
              };
            };
          };
        };

        config = {
          secrets =
            let
              escapedAddress = lib.replaceStrings [ "@" ] [ "__" ] name;
            in
            {
              imap = lib.mkDefault "imap/passwords/${escapedAddress}";
              smtp = lib.mkDefault "smtp/passwords/${escapedAddress}";
            };
        };
      }));
    };

    localDomains = lib.mkOption {
      default = [ ];
      type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
    };

    outboundAuthorizedUsers = lib.mkOption {
      default = [ ];
      type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
    };
  };
}
