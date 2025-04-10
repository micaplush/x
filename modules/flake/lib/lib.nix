{ inputs, lib, pkgs, ... }:

let
  inherit (inputs.gitignorenix.lib) gitignoreFilterWith;

  pkgsBasePath = ../../../pkgs;
in
{
  inherit pkgsBasePath;

  buildGoModule = { name, ... }@args:
    let
      referencedMods = lib.pipe (pkgsBasePath + "/${name}/go.mod") [
        builtins.readFile
        (lib.splitString "\n")
        (builtins.map (builtins.match ''replace [a-z0-9./-]+/[a-z0-9-]+ v0\.0\.0-local => \.\./([a-z0-9-]+)''))
        (builtins.filter (match: match != null))
        (builtins.map (match: builtins.elemAt match 0))
      ];

      modsToKeep = referencedMods ++ [ name ];

      passthroughArgs = builtins.removeAttrs args [ "name" ];
    in
    pkgs.buildGoModule (passthroughArgs // {
      pname = name;
      version = "none";

      src = lib.sources.cleanSourceWith {
        filter = gitignoreFilterWith {
          basePath = pkgsBasePath;
          extraRules = ''
            /*
            ${lib.pipe modsToKeep [
              (builtins.map(m: "!/${m}"))
              (builtins.concatStringsSep "\n")
            ]}
          '';
        };
        src = pkgsBasePath;
      };

      modRoot = name;
      meta.mainProgram = name;
    });

  mkIfElse = condition: ifValue: elseValue: lib.mkMerge [
    (lib.mkIf condition ifValue)
    (lib.mkIf (!condition) elseValue)
  ];

  nixpkgs = lib;
}
