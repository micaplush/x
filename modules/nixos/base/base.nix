{ config, name, ... }:

{
  assertions = [
    {
      assertion = config.networking.hostId != null;
      message = "networking.hostId not set";
    }
  ];

  networking.hostName = name;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Vienna";

  x.base.filesystems.persistentDirectories = [
    "/etc/nixos"
    "/var/lib/nixos"
    "/var/lib/systemd/timers"
    "/var/log"
  ];

  system.activationScripts.mount-dirs.text = ''
    mkdir -p /mnt/{1..5}
  '';

  environment.etc.machine-id.source = "${config.x.base.filesystems.persistDirectory}/etc/machine-id";
}
