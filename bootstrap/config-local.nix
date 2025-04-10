{ hostID, agenixKey, agenixPublicKey, diskSize, nixosVersion, ... }:

''
  { lib, name, modulesPath, ... }:

  {
    imports = [
      "''${modulesPath}/profiles/qemu-guest.nix"
    ];

    networking.hostId = "${hostID}";

    x.base.agenix.keys = lib.singleton "${agenixKey}";
    x.base.filesystems.virtual.diskSize = "${diskSize}";

    x.global.agenix.publicKeys.''${name} = [
      "${agenixPublicKey}"
    ];

    x.bootstrap.local.enable = true;

    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "${nixosVersion}";
  }
''
