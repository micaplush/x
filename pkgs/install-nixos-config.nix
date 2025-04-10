{ lib, pkgs, ... }:

pkgs.writeShellApplication {
  name = "install-nixos-config";

  runtimeInputs = with pkgs; [ coreutils nix ];

  text = ''
    readonly activate_op="$1"
    readonly store_path="$2"

    nix-store --realise "$store_path"

    case "$activate_op" in
      boot | switch)
        nix-env -p /nix/var/nix/profiles/system --set "$store_path"
        ;;
    esac

    case "$activate_op" in
      boot | dry-activate | switch | test)
        "$store_path/bin/switch-to-configuration" "$activate_op"
        ;;
    esac
  '';

  meta.platforms = lib.platforms.linux;
}
