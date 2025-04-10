{ lib, name, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostId = "redacted";
  boot.kernelParams = [ "console=ttyS0,115200n8" ];

  x.base.agenix.keys = lib.singleton "key_2024-11-03";
  x.global.agenix.publicKeys.${name} = [
    "ageREDACTED"
  ];

  x.base = {
    filesystems.physical2.diskDevice = "/dev/disk/by-id/ata-DOGFISH_SSD_128GB_...";
    secureboot.enable = false;
  };

  x.server.enable = true;

  x.services = {
    resticRestServer.enable = true;
    stepca.enable = true;
  };

  system.stateVersion = "24.05";
}
