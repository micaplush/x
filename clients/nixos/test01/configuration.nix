{ lib, name, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  networking.hostId = "redacted";

  x.base.agenix.keys = lib.singleton "key_2024-10-16";

  x.base.filesystems.virtual = {
    diskDevice = "/dev/vda";
    diskSize = "40G";
  };

  x.global.agenix.publicKeys.${name} = [
    "ageREDACTED"
  ];

  x.base = {
    restic.enableAutomaticBackups = false;
    secureboot.enable = false;
  };

  x.server.enable = true;

  x.server.caddy.services.example.extraConfig = ''
    file_server {
      root ${./content}
      browse
    }

    header {
      -ETag
      -Last-Modified
    }
  '';

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.05";
}

