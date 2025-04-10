{ lib, pkgs, self, ... }:

let
  name = "paperless-labelgen";
in
self.lib.buildGoModule {
  inherit name;
  vendorHash = "sha256-7uZqkrJBqIFTGiWrBhMZjftO2VuD6ww9OF9dAialoXI=";

  buildInputs = [ pkgs.makeWrapper ];

  ldflags = [
    "-X tbx.at/paperless-labelgen/label.FontPath=${pkgs.courier-prime}"
  ];

  postInstall =
    let
      path = lib.makeBinPath (with pkgs; [
        cups
      ]);
    in
    ''
      wrapProgram "$out/bin/${name}" \
        --prefix PATH ":" ${path}
    '';
}

