{ inputs, lib, self, withSystem, ... }:

let
  gatherModules = path:
    if (lib.pathIsRegularFile path) || (lib.pathIsRegularFile ./${path}/default.nix)
    then [ path ]
    else
      lib.pipe path [
        builtins.readDir
        (lib.filterAttrs (filename: type: type == "directory" || (lib.hasSuffix ".nix" filename)))
        (lib.mapAttrsToList (filename: type: gatherModules (path + "/${filename}")))
      ];

  gatherActiveModules = path: lib.pipe path [
    gatherModules
    lib.flatten
    (builtins.filter (path:
      let pathStr = lib.path.removePrefix ../../. path;
      in !(lib.hasSuffix ".off" pathStr) && !(lib.hasSuffix ".off.nix" pathStr)))
  ];

  globalModules = gatherActiveModules ../global;

  configWithPrio = lib.mapAttrsRecursiveCond
    (attrset: !(attrset ? _type && attrset._type == "option"))
    (path: option: lib.mkOverride option.highestPrio option.value);

  globalDefinitionsToplevel = gatherActiveModules ../globaldata;

  globalDefinitionsFromHosts = lib.mapAttrsToList
    (hostname: host: { x.global = configWithPrio host.options.x.global; })
    nixosConfigurations;

  globalConfig = lib.evalModules {
    modules = lib.flatten [
      globalModules
      globalDefinitionsToplevel
      globalDefinitionsFromHosts
    ];

    specialArgs = {
      inherit self;
      deps = inputs;
      globalConfig = throw "Accessing globalConfig in the evalutation for globals is forbidden.";
      localEval = false;
      name = throw "Accessing name in the evalutation for globals is forbidden.";
    };
  };

  localModules = gatherActiveModules ../nixos;
  hostModules = hostname: gatherActiveModules ../../clients/nixos/${hostname};

  hostConfig = hostname: inputs.nixpkgs.lib.nixosSystem {
    modules = lib.flatten [
      globalModules
      localModules
      (hostModules hostname)

      ({ config, ... }: {
        _module.args = withSystem config.nixpkgs.hostPlatform.system ({ inputs', self', ... }: {
          inherit inputs' self';
        });
      })
    ];

    specialArgs = {
      inherit self;
      deps = inputs;
      globalConfig = globalConfig.config.x.global;
      localEval = true;
      name = hostname;
    };
  };

  nixosConfigurations = lib.pipe ../../clients/nixos [
    builtins.readDir
    (builtins.mapAttrs (hostname: lib.const (hostConfig hostname)))
  ];
in
{
  options = {
    globalConfig = lib.mkOption {
      type = lib.types.attrs;
    };
  };

  config = {
    flake = {
      inherit globalConfig nixosConfigurations;
    };
  };
}
