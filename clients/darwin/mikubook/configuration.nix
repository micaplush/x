{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    neovim
    jq
    qrencode
    just
    nixpkgs-fmt
    htop
  ];

  networking = {
    computerName = "mikubook";
    hostName = "mikubook";
    knownNetworkServices = [ "Tailscale" ];
    search = [ "in.tbx.at" ];
  };

  fonts.packages = [ pkgs.fira-code ];

  homebrew.enable = true;

  homebrew.casks = [
    { name = "betterdisplay"; }
    { name = "bluesnooze"; }
    { name = "element"; }
    { name = "firefox"; }
    { name = "gimp"; }
    { name = "hiddenbar"; }
    { name = "imazing-profile-editor"; }
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

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  home-manager.users.mica = {
    home.stateVersion = "24.11";
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
