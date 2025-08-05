{ pkgs, lib, system, ... }:

# The scripts of this package are taken from https://github.com/ewanmellor/git-diff-image.
#
# They have been modified heavily:
#
#   - Checks for graceful errors in case of missing dependencies have been removed.
#   - Images are not arranged in a montage (a 1x3 tile configuration) but opened individually.
#   - To implement opening multiple images, the dependency on imv is hardcoded instead of using xdg-open (which can only open one image at a time).
#   - Compatibility code with GraphicsMagick instead of ImageMagick has been removed.
#   - Compatibility code with macOS has been changed.

let
  isLinux = lib.elem system lib.platforms.linux;

  path = lib.makeBinPath (with pkgs; lib.flatten [
    exiftool
    imagemagick
    (lib.optional isLinux imv)
  ]);
in
pkgs.runCommand "git-diff-image"
{
  buildInputs = [ pkgs.makeWrapper ];
} ''
  mkdir -p $out/bin
  cp ${./diff-image} $out/bin/diff-image
  cp ${./git_diff_image} $out/bin/git_diff_image

  wrapProgram $out/bin/diff-image \
    --prefix PATH : ${lib.escapeShellArg path}
''
