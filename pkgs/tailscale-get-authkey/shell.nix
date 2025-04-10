{ pkgs ? import <nixpkgs> { }, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    delve
    go
  ];
}
