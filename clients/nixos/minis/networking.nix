{
  networking.networkmanager.ensureProfiles.profiles = {
    bridge-vm0 = {
      connection = {
        id = "bridge-vm0";
        type = "bridge";
        autoconnect = true;
        interface-name = "vm0";
      };

      bridge.stp = false;

      ipv4 = {
        method = "manual";
        addresses = "192.168.7.10/24";
        dns = "192.168.7.1";
        gateway = "192.168.7.1";
      };
    };

    bridge-vm0-eno1 = {
      connection = {
        id = "bridge-vm0-eno1";
        type = "802-3-ethernet";
        autoconnect = true;
        interface-name = "eno1";

        controller = "vm0";
        master = "vm0";
        slave-type = "bridge";
        port-type = "bridge";
      };
    };
  };
}
