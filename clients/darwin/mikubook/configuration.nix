{ config, deps, globalConfig, pkgs, lib, ... }:

{
  imports = [
    deps.home-manager.darwinModules.home-manager
    deps.mac-app-util.darwinModules.default
  ];
  environment.systemPackages = with pkgs; [
    neovim
    jq
    qrencode
    just
    nixpkgs-fmt
    htop
  ];

  networking.hostName = "mikubook";
  networking.computerName = "mikubook";

  networking.search = [ "in.tbx.at" ];

  networking.knownNetworkServices = [ "Tailscale" ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  environment.shellAliases = {
    g = "git";
    lg = "lazygit";
  };

  environment.shells = [ pkgs.fish ];

  programs.fish.shellInit = ''
    fish_add_path /opt/homebrew/bin
  '';

  programs.fish.interactiveShellInit = ''
    tailscale completion fish | source
  '';

  fonts.packages = [ pkgs.fira-code ];

  homebrew.enable = true;

  homebrew.brews = [
    { name = "mpc"; }
    { name = "ncmpcpp"; }
  ];

  homebrew.casks = [
    { name = "betterdisplay"; }
    { name = "bluesnooze"; }
    { name = "element"; }
    { name = "firefox"; }
    { name = "gimp"; }
    { name = "hiddenbar"; }
    { name = "imazing-profile-editor"; }
    { name = "iTerm2"; }
    { name = "karabiner-elements"; }
    { name = "keepassxc"; }
    { name = "launchcontrol"; }
    { name = "librewolf"; args.no_quarantine = true; }
    { name = "middleclick"; args.no_quarantine = true; }
    { name = "signal"; }
    { name = "steermouse"; }
    { name = "syncthing-app"; }
    { name = "tailscale-app"; }
    { name = "tor-browser"; }
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  launchd.agents.ssh-agent = { };

  users.users.mica = {
    uid = 501;
    home = "/Users/mica";
    shell = pkgs.fish;
  };

  users.knownUsers = [ config.users.users.mica.name ];

  system.primaryUser = config.users.users.mica.name;

  programs.direnv.enable = true;

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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.sharedModules = [
    deps.mac-app-util.homeManagerModules.default
  ];

  home-manager.users.mica = { lib, ... }: {
    programs.git = {
      enable = true;
      userName = "Mica";
      userEmail = "hatsune@mica.lgbt";
      lfs.enable = true;
      signing = {
        key = "4F27E6C79ADB2956733DBC75FE48DC29190F4D0E";
        signByDefault = true;
      };
    };

    programs.gpg.enable = true;

    home.activation.iterm-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run cp -f $VERBOSE_ARG \
          ${builtins.toPath ./iterm2.plist} $HOME/Data/iTerm2/com.googlecode.iterm2.plist
    '';

    programs.ssh.extraConfig =
      let
        hosts = lib.pipe globalConfig.netsrv.hosts [
          lib.attrNames
          (lib.filter (hostname: globalConfig.netsrv.services ? "ssh.${hostname}"))
        ];
      in
      ''
        Host github.com
            IdentityFile ~/.ssh/id_github_ed25519

        Host *.in.tbx.at,${builtins.concatStringsSep "," hosts}
            IdentityFile ~/.ssh/id_internal_ed25519

        Host *
            UseKeychain yes
            AddKeysToAgent yes
      '';

    programs.vscode = {
      enable = true;
      package = deps.nixpkgs-unstable.legacyPackages.aarch64-darwin.vscodium;

      profiles.default = {
        userSettings = {
          # Font settings
          "editor.fontFamily" = "'Fira Code', 'Droid Sans Mono', 'monospace', monospace, 'Droid Sans Fallback'";
          "editor.fontLigatures" = true;
          "editor.fontSize" = 14;

          # Scrolling & zooming
          "editor.mouseWheelScrollSensitivity" = 3;
          "editor.mouseWheelZoom" = true;
          "window.zoomLevel" = 0;

          # Disable online services and telemetry
          "extensions.autoCheckUpdates" = false;
          "extensions.autoUpdate" = false;
          "go.toolsManagement.checkForUpdates" = "off";
          "npm.fetchOnlinePackageInfo" = false;
          "python.experiments.enabled" = false;
          "typescript.disableAutomaticTypeAcquisition" = true;
          "update.mode" = "none";
          "update.showReleaseNotes" = false;
          "workbench.enableExperiments" = false;
          "workbench.settings.enableNaturalLanguageSearch" = false;
          "workbench.welcomePage.extraAnnouncements" = false;

          # Other settings
          "breadcrumbs.enabled" = false;
          "editor.formatOnSave" = true;
          "editor.minimap.autohide" = true;
          "files.autoSave" = "onFocusChange";
          "go.showWelcome" = false;
          "window.menuBarVisibility" = "toggle";
          "workbench.colorTheme" = "GitHub Dark Default";
          "workbench.remoteIndicator.showExtensionRecommendations" = false;
          "workbench.startupEditor" = "none";
          "workbench.welcomePage.walkthroughs.openOnInstall" = false;
          "zenMode.centerLayout" = false;
          "zenMode.fullScreen" = false;

          # Fuck AI
          "chat.commandCenter.enabled" = false;

          # Nix
          "nix.enableLanguageServer" = true;
          "nix.hiddenLanguageServerErrors" = [
            "textDocument/definition"
          ];
          "nix.serverPath" = lib.getExe pkgs.nixd;
          "nix.serverSettings".nixd = {
            formatting.command = [ "nixpkgs-fmt" ];
          };
        };

        extensions = with pkgs.vscode-marketplace; [
          esbenp.prettier-vscode
          github.github-vscode-theme
          golang.go
          jnoortheen.nix-ide
          ms-python.debugpy
          ms-python.python
          redhat.vscode-xml
        ];
      };
    };

    programs.lazygit = {
      enable = true;
      settings = {
        git.autoForwardBranches = "none";
      };
    };

    home.stateVersion = "24.11";
  };

  programs.ssh.knownHosts =
    let
      extraHostNames = {
        minis = [ "forge.in.tbx.at" ];
      };

      internalHosts = lib.pipe ../../../secrets/derived/ssh-public-keys [
        builtins.readDir
        (lib.mapAttrs' (k: v:
          let
            hostName = "${k}.in.tbx.at";
          in
          {
            name = hostName;
            value = {
              publicKeyFile = ../../../secrets/derived/ssh-public-keys/${k}/ed25519;
              hostNames = [ hostName k ] ++ (if extraHostNames ? ${k} then extraHostNames.${k} else [ ]);
            };
          }))
      ];

      otherHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };

      knownHosts = otherHosts // internalHosts;
    in
    knownHosts;

  nixpkgs.overlays = [
    deps.nix-vscode-extensions.overlays.default
  ];

  nix.settings.trusted-users = [ "@admin" ];

  nix.settings.experimental-features = "nix-command flakes";
  nix.channel.enable = false;

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "minis.in.tbx.at";
      sshUser = "remotebuild";
      sshKey = "~root/.ssh/id_internal-nixbuild_ed25519";
      system = "x86_64-linux";
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
      speedFactor = 10;
      maxJobs = 16;
      protocol = "ssh-ng";
    }
  ];

  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
