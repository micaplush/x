{ config, deps, globalConfig, lib, name, pkgs, ... }:

let
  cfg = config.x.base.agenix;

  inherit (deps) agenix;
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.x.base.agenix = {
    keys = lib.mkOption {
      default = [ ];
      description = "File names of agenix private keys.";
      type = with lib.types; listOf str;
    };
  };

  config = {
    assertions = [
      {
        assertion = (builtins.length cfg.keys) > 0;
        message = "No agenix private keys specified (in x.base.agenix.keys).";
      }
    ];

    age = {
      ageBin = "${pkgs.age}/bin/age";
      identityPaths = builtins.map (k: "${config.x.base.filesystems.persistDirectory}/agenix/${k}") cfg.keys;

      secrets = lib.pipe globalConfig.agenix.secretMounts [
        (lib.filterAttrs (mountName: mount: mount.host == name))
        (lib.mapAttrs (mountName: mount: {
          inherit (mount) owner group mode path;
          file = ../../../secrets/data/${mount.secret}.age;
        }))
      ];
    };

    environment.systemPackages = [
      (agenix.packages.x86_64-linux.default.override {
        ageBin = config.age.ageBin;
      })

      pkgs.age
    ];
  };
}
