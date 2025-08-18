{ inputs, ... }:

{
  flake.packages.x86_64-linux.pve-installer-iso = inputs.nixos-generators.nixosGenerate {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
    ];

    specialArgs = {
      deps = inputs;
    };

    format = "iso";
  };
}
