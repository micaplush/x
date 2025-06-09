{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    gitignorenix = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";


    # Revision is fixed to the latest version published on channels.nixos.org (at the time of writing).
    # This avoids a lot of tedious rebuilding because the caches for the latest commits on the unstable branch are not always warm.
    # The revision to set can be obtained from: https://channels.nixos.org/nixos-unstable/git-revision.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/3e3afe5174c561dee0df6f2c2b2236990146329f";
  };

  outputs = inputs@{ flake-parts, gitignorenix, lix-module, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/flake/configurations.nix
        ./modules/flake/devshell-default.nix
        ./modules/flake/devshells-pkgs.nix
        ./modules/flake/justfile.nix
        ./modules/flake/lib
        ./modules/flake/overlay.nix
        ./modules/flake/packages.nix
        ./modules/flake/secrets.nix
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };
}
