{
  perSystem = { lib, pkgs, self', system, ... }:
    let
      inherit (self'.lib) pkgsBasePath;
    in
    {
      packages = lib.pipe pkgsBasePath [
        builtins.readDir
        builtins.attrNames
        (builtins.map (name: {
          name = lib.removeSuffix ".nix" name;
          value = pkgs.callPackage (pkgsBasePath + "/${name}") { self = self'; };
        }))
        (builtins.filter ({ value, ... }: lib.meta.availableOn { inherit system; } value))
        lib.listToAttrs
      ];
    };
}
