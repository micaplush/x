{ deps, pkgs, lib, ... }:

{
  homebrew.brews = [
    { name = "mpc"; }
    { name = "ncmpcpp"; }
  ];

  launchd.user.agents.mpd =
    let
      pkg = deps.nixpkgs-unstable.legacyPackages.aarch64-darwin.mpd;

      config = pkgs.writeText "mpd.conf" ''
        music_directory "~/Media/music"
        playlist_directory "~/.mpd/playlists"
        db_file "~/.mpd/mpd.db"
        log_file "~/.mpd/mpd.log"
        pid_file "~/.mpd/mpd.pid"
        state_file "~/.mpd/mpdstate"

        bind_to_address "127.0.0.1"

        zeroconf_enabled "no"
      '';
    in
    {
      serviceConfig = {
        ProgramArguments = [ (lib.getExe pkg) "--no-daemon" config.outPath ];
        KeepAlive = true;
        RunAtLoad = true;
        EnvironmentVariables = {
          PATH = "${pkg}/bin";
        };
        ProcessType = "Interactive";
      };
    };

  home-manager.users.mica = {
    home.file.".config/ncmpcpp/config".text = ''
      mpd_music_dir = "~/Media/music"
    '';
  };
}
