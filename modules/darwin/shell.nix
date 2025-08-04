{ pkgs, ... }:

{
  users.users.mica.shell = pkgs.fish;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  environment.shellAliases = {
    g = "git";
    lg = "lazygit";
  };

  environment.shells = [ pkgs.fish ];

  programs.fish = {
    enable = true;

    shellInit = ''
      fish_add_path /opt/homebrew/bin
    '';

    interactiveShellInit = ''
      tailscale completion fish | source
    '';
  };
}
