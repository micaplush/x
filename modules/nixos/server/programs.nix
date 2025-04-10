{ config, lib, pkgs, ... }:

{
  environment.systemPackages = lib.mkIf config.x.server.enable (with pkgs; [
    acpi
    curl
    dig
    entr
    file
    fx
    htop
    jq
    nethogs
    nix-tree
    openssl
    qrencode
    ripgrep
    tmux
    tree
    unzip
    usb-reset
    usbutils
    zip
  ]);
}
