{ config, ... }:

{
  x.global.users = {
    accounts = {
      mica = {
        displayName = "Mica";
        isAdmin = true;

        local.authorizedKeys = [
          "ssh-ed25519 AAAAREDACTED"
          "ssh-ed25519 AAAAREDACTED"
        ];
      };
    };

    rootAuthorizedKeys = config.x.global.users.accounts.mica.local.authorizedKeys;
  };
}
