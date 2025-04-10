{
  perSystem = { lib, pkgs, self', system, ... }:
    let
      inherit (self'.lib) pkgsBasePath;
    in
    {
      devShells = lib.pipe pkgsBasePath [
        builtins.readDir
        builtins.attrNames
        (builtins.map (fname: {
          pkgName = fname;
          entryPoint = (pkgsBasePath + "/${fname}/shell.nix");
        }))
        (builtins.filter ({ entryPoint, ... }: lib.pathIsRegularFile entryPoint))
        (builtins.map ({ pkgName, entryPoint }: {
          ${pkgName} = import entryPoint { inherit lib pkgs system; };
        }))
        lib.mergeAttrsList
      ];
    };
}
