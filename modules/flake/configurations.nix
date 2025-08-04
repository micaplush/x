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

  configWithPrio = lib.mapAttrsRecursiveCond
    (attrset: !(attrset ? _type && attrset._type == "option"))
    (path: option: lib.mkOverride option.highestPrio option.value);

  globalDefinitionsFromEvals = lib.map (eval: { x.global = configWithPrio eval.options.x.global; });

  evalGlobalmods = { globalModules, localEvals }: lib.evalModules {
    modules = lib.concatLists [
      globalModules
      (globalDefinitionsFromEvals localEvals)
    ];

    specialArgs = {
      inherit self;
      deps = inputs;
      globalConfig = throw "Accessing globalConfig in the evalutation for globals is forbidden.";
      localEval = false;
      name = throw "Accessing name in the evalutation for globals is forbidden.";
    };
  };

  globalModules = gatherActiveModules ../global;
  globalDefinitionsToplevel = gatherActiveModules ../globaldata;

  globalConfig = evalGlobalmods {
    globalModules = lib.flatten [
      globalModules
      globalDefinitionsToplevel
    ];

    localEvals = lib.pipe [
      darwinConfigurations
      nixosConfigurations
    ] [
      (lib.map lib.attrValues)
      lib.concatLists
    ];
  };

  nixosLocalModules = gatherActiveModules ../nixos;
  nixosHostModules = hostname: gatherActiveModules ../../clients/nixos/${hostname};

  nixosConfig = hostname: inputs.nixpkgs.lib.nixosSystem {
    modules = lib.flatten [
      globalModules
      nixosLocalModules
      (nixosHostModules hostname)

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
    (builtins.mapAttrs (hostname: lib.const (nixosConfig hostname)))
  ];

  darwinLocalModules = gatherActiveModules ../darwin;
  darwinHostModules = hostname: [ ../../clients/darwin/${hostname}/configuration.nix ];

  darwinConfig = hostname: inputs.nix-darwin.lib.darwinSystem {
    modules = lib.flatten [
      globalModules
      darwinLocalModules
      (darwinHostModules hostname)

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

  darwinConfigurations = lib.pipe ../../clients/darwin [
    builtins.readDir
    (builtins.mapAttrs (hostname: lib.const (darwinConfig hostname)))
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
      inherit globalConfig nixosConfigurations darwinConfigurations;
    };
  };
}
