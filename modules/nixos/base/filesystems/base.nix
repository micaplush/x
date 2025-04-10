{ deps, lib, ... }:

let
  inherit (deps) impermanence;
in
{
  imports = [
    impermanence.nixosModules.impermanence
  ];

  options.x.base.filesystems = {
    persistDirectory = lib.mkOption {
      default = "/persist";
      description = "The directory where the persistent subvolume is mounted.";
      type = lib.types.path;
    };

    persistentDirectories = lib.mkOption {
      default = [ ];
      description = ''
        Directories to persist on a system level. These are owned by root per default and use absolute paths.
      '';
      type = with lib.types; listOf (either attrs path); # No proper type here because getting types out of another module is annoying.
    };

    swapfileResumeOffset = lib.mkOption {
      type = lib.types.int;
    };
  };
}
