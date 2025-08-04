{ deps, pkgs, ... }:

{
  home-manager.users.mica = { lib, ... }: {
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
  };

  nixpkgs.overlays = [
    deps.nix-vscode-extensions.overlays.default
  ];
}
