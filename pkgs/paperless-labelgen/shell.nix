{ pkgs ? import <nixpkgs> { }, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    delve
    go
  ];

  LABELGEN_FONT = pkgs.courier-prime.outPath;
}
