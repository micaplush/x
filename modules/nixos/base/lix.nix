{ deps, ... }:

let
  inherit (deps) lix-module;
in
{
  imports = [
    lix-module.nixosModules.default
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
