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
      complete git --condition '__fish_git_using_command fixup reword split' --no-files --keep-order --arguments '(__fish_git_recent_commits)'

      tailscale completion fish | source
    '';
  };
}
