{ hostID, agenixKey, agenixPublicKey, nixosVersion, ... }:

''
  { lib, name, modulesPath, ... }:

  {
    imports = [
      "''${modulesPath}/profiles/qemu-guest.nix"
    ];

    networking.hostId = "${hostID}";

    x.base.agenix.keys = lib.singleton "${agenixKey}";
    x.global.agenix.publicKeys.''${name} = [
      "${agenixPublicKey}"
    ];

    x.bootstrap.hetzner.enable = true;

    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "${nixosVersion}";
  }
''
