{ inputs, self, ... }:

{
  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.lix-module.overlays.default
        self.overlays.default
      ];
      config = { };
    };
  };

  flake.overlays.default = prev: final: {
    inherit (inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system})
      authelia
      cloc# cloc v2.00 (the current version in stable) ignores `--fullpath` for `--not-match-f` which is used in the root devshell.
      just
      tailscale;
  };
}
