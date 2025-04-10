{ flake-parts-lib, inputs, ... }:

{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption ({ lib, pkgs, ... }: {
      options = {
        lib = lib.mkOption {
          type = lib.types.attrs;
        };
      };

      config = {
        lib = (import ./lib.nix) { inherit inputs lib pkgs; };
      };
    });
  };

  config = {
    transposition.lib = { };
  };
}
