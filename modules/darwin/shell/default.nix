{ pkgs, ... }:

{
  users.users.mica.shell = pkgs.fish;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  environment.shellAliases = {
    chx = "chmod +x";
    g = "git";
    gl = "git log";
    gs = "git status";
    lg = "lazygit";
    nsh = "nix-shell --packages fish --run fish";
  };

  environment.shells = [ pkgs.fish ];

  programs.fish = {
    enable = true;

    shellInit = ''
      fish_add_path /opt/homebrew/bin
    '';

    interactiveShellInit = ''
      function rpw
        realpath (which $argv[1])
      end
      complete --command rpw --exclusive --arguments '(__fish_complete_command)'

      complete git --condition '__fish_git_using_command fixup reword split' --no-files --keep-order --arguments '(__fish_git_recent_commits)'

      tailscale completion fish | source
    '';
  };
}
