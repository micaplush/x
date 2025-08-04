{ deps, ... }:

{
  imports = [
    deps.home-manager.darwinModules.home-manager
    deps.mac-app-util.darwinModules.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    sharedModules = [
      deps.mac-app-util.homeManagerModules.default
    ];
  };
}
