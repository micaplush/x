{ config, lib, pkgs, ... }:

let
  cfg = config.x.peripherals.labelprinter;
in
{
  options.x.peripherals.labelprinter = {
    enable = lib.mkEnableOption "connection to the label printer";

    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    x.peripherals.labelprinter.name = "labelprinter";

    services.printing = {
      enable = true;
      drivers = [ pkgs.ptouch-driver ];
      extraConf = "WebInterface no";
    };

    hardware.printers = {
      ensurePrinters = [
        {
          name = cfg.name;
          deviceUri = "usb://Brother/QL-600?serial=...";
          model = "ptouch-driver/Brother-QL-600-ptouch-ql.ppd.gz";
        }
      ];
      ensureDefaultPrinter = cfg.name;
    };
  };
}
