{
  x.global.email = {
    localDomains = [
      "mica.lgbt"
      "tbx.at"
    ];

    outboundAuthorizedUsers = [
      "postmaster@tbx.at"
    ];

    accounts = {
      "postmaster@tbx.at" = {
        # Export it out of mailbox.org by going to the aliases page, then running that in the console:
        # [...document.querySelectorAll(".alias_table tr:not([class]) > td:not([class])")].map(e => e.innerText.trim()).filter(a => a !== "" && !a.endsWith("@mailbox.org")).sort()
        aliases = builtins.fromJSON (builtins.readFile ./aliases.json);

        permissions = {
          send = true;
          receive = true;
        };

        sync = {
          enable = true;
          retrieval = {
            idleMailbox = "INBOX";
            mailboxes = [ "INBOX" "Spam" ];
          };
        };
      };
    };
  };
}
