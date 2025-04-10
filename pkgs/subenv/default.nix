{ bubblewrap, lib, nix, python3, stdenv, ... }:

stdenv.mkDerivation {
  name = "subenv";

  buildInputs = [
    (python3.withPackages (pythonPackages: with pythonPackages; [
      click
    ]))

    bubblewrap
    nix
  ];

  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out/bin
    cp ${./subenv.py} $out/bin/subenv
    chmod +x $out/bin/subenv

    completions_path="$out/share/fish/vendor_completions.d"
    mkdir -p "$completions_path"
    _SUBENV_COMPLETE=fish_source python $out/bin/subenv > $completions_path/subenv.fish
  '';

  meta.platforms = lib.platforms.linux;
}

