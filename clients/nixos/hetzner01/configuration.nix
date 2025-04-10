{ lib, name, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  networking.hostId = "redacted";

  x.base.agenix.keys = lib.singleton "key_2024-10-24";
  x.global.agenix.publicKeys.${name} = [
    "ageREDACTED"
  ];

  x.base = {
    filesystems.virtual.diskDevice = "/dev/sda";
    networking.macAddressGeneration = "permanent";
    restic.enableAutomaticBackups = false;
    secureboot.enable = false;
  };

  x.server.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.05";
}

