{ config, lib, ... }:

let
  cfg = config.x.base.localport;
in
{
  options.x.base.localport = {
    decls = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule { });
    };

    ports = lib.mkOption {
      readOnly = true;
      type = lib.types.attrsOf lib.types.port;
    };
  };

  config.x.base.localport.ports = (lib.foldlAttrs
    (acc: name: val:
      lib.recursiveUpdate acc {
        nextPort = acc.nextPort + 1;
        values.${name} = acc.nextPort;
      })
    { nextPort = 7000; values = { }; }
    cfg.decls).values;
}
