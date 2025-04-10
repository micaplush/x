let
  flakeOutputs = import ../flake-compat.nix;
  lib = flakeOutputs.lib.${builtins.currentSystem}.nixpkgs;

  inherit (flakeOutputs) secretsAdminPublicKeys;

  secretsGenerationData = flakeOutputs.secretsGenerationData.${builtins.currentSystem};

  publicKeysForHosts = hosts: lib.pipe hosts [
    (builtins.map (hostname: secretsGenerationData.publicKeys.${hostname}))
    lib.flatten
  ];

  hostsForSecret = secretName: lib.pipe secretsGenerationData.secretMounts [
    (lib.filterAttrs (mountName: mount: mount.secret == secretName))
    (lib.mapAttrsToList (mountName: mount: mount.host))
  ];

  secrets = lib.mapAttrs'
    (secretName: secret: {
      name = "data/${secretName}.age";
      value.publicKeys = secretsAdminPublicKeys ++ (publicKeysForHosts (hostsForSecret secretName));
    })
    secretsGenerationData.secrets;
in
secrets
