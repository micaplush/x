{ lib, pkgs, self', ... }:

let
  diffImageAttributesFile = pkgs.writeText "gitattributes-diff-image" ''
    *.gif diff=image
    *.jpeg diff=image
    *.jpg diff=image
    *.png diff=image
  '';

  diffImageAlias = visualDiff: ''!f() { cd -- "''${GIT_PREFIX:-.}"; ${lib.optionalString visualDiff "GIT_DIFF_IMAGE_ENABLED=1"} git -c core.attributesFile=${diffImageAttributesFile} -c diff.image.command=${self'.packages.git-diff-image}/bin/git_diff_image diff "$@"; }; f'';
in
{
  environment.variables.GIT_SEQUENCE_EDITOR = lib.getExe (pkgs.writeShellApplication {
    name = "nvim-rebase-interactive";

    # Using Neovim from the environment is a bit disgusting but that's
    # the only way I've found to make it use my options when
    # configuring it through the NixOS module.
    runtimeInputs = with pkgs; [ coreutils gnugrep ];

    text = ''
      readonly file="$1"

      if grep -qE "^fixup " "$file"; then
        nvim "$file" "+$(grep -nE "^fixup " "$file" | head -n 1 | cut -d : -f 1)"
      else
        nvim "$file"
      fi
    '';
  });

  environment.systemPackages =
    let
      git-default-branch = pkgs.writeShellApplication {
        name = "git-default-branch";
        runtimeInputs = [ pkgs.git ];
        text =
          let
            branches = [
              "main"
              "master"
              "test"
            ];
            checks = lib.pipe branches [
              (builtins.map (branch: ''
                if git rev-parse --verify ${branch} > /dev/null 2>&1; then
                  echo ${branch}
                  exit
                fi
              ''))
              (builtins.concatStringsSep "\n")
            ];
          in
          ''
            ${checks}
            echo "no default branch found" >&2
            exit 1
          '';
      };

      git-fixup = pkgs.writeShellApplication {
        name = "git-fixup";
        runtimeInputs = [ pkgs.git ];
        text = ''
          export GIT_SEQUENCE_EDITOR=true
          revision=$(git rev-parse "$1")
          git commit --fixup "$@"
          git rebase --interactive --autostash --autosquash "$revision^"
        '';
      };

      git-split = pkgs.writeShellApplication {
        name = "git-split";
        runtimeInputs = with pkgs; [ coreutils git git-revise gnused ];
        text = ''
          revision="$(git rev-parse "$1")"
          default_branch=$(git default-branch)
          EDITOR="sed -E '1{/^\[1\] / {s/.*/git log --pretty=%s -n 1 $(git log --pretty=%P -n 1 "$revision")/e;s/^/fixup! /;q};s/^\[2\] //}' -i" git revise --cut --no-index "$revision"
          git rebase --interactive --autostash --autosquash --keep-base "$default_branch"
        '';
      };

    in
    [
      git-default-branch
      git-fixup
      git-split
      pkgs.git-revise
    ];

  home-manager.users.mica = {
    programs.git = {
      enable = true;
      userName = "Mica";
      userEmail = "hatsune@mica.lgbt";
      lfs.enable = true;
      signing = {
        key = "4F27E6C79ADB2956733DBC75FE48DC29190F4D0E";
        signByDefault = true;
      };

      aliases = {
        "rec" = "!git checkout -B recovery && git checkout -";
        a = "add";
        b = "branch";
        c = "commit";
        ca = "commit --amend";
        can = "commit --amend --no-edit";
        ch = "checkout";
        cl = "clean";
        cp = "cherry-pick";
        current-branch = "rev-parse --abbrev-ref HEAD";
        d = "diff";
        dc = "diff --cached";
        di = "diff-image";
        dix = "diff-image-exif";
        diff-image = diffImageAlias true;
        diff-image-exif = diffImageAlias false;
        f = "fetch";
        fu = "fixup";
        l = "log";
        lp = "log --patch-with-stat";
        ls = "log --stat";
        p = "push";
        pf = "push --force";
        pl = "pull --rebase";
        r = "rebase";
        rc = "rebase --continue";
        reword = "revise --edit --no-index";
        rh = "reset --hard";
        ri = "rebase --interactive --autostash --autosquash --keep-base";
        rs = "restore --staged";
        rw = "reword";
        s = "status";
        st = "stash";
      };
    };

    programs.lazygit = {
      enable = true;
      settings = {
        git.autoForwardBranches = "none";
      };
    };
  };
}
