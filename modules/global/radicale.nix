{ lib, ... }:

{
  options.x.global.radicale = {
    users = lib.mkOption {
      default = [ ];
      type = with lib.types; coercedTo (listOf str) lib.unique (listOf str);
    };
  };
}
