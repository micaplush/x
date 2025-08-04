{ config, ... }:

{
  users.users.mica = {
    uid = 501;
    home = "/Users/mica";
  };

  users.knownUsers = [ config.users.users.mica.name ];

  system.primaryUser = config.users.users.mica.name;
}
