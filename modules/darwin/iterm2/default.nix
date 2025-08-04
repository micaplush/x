{
  homebrew.casks = [
    { name = "iTerm2"; }
  ];

  home-manager.users.mica = { lib, ... }: {
    home.activation.iterm-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run cp -f $VERBOSE_ARG \
          ${builtins.toPath ./iterm2.plist} $HOME/Data/iTerm2/com.googlecode.iterm2.plist
    '';
  };
}
