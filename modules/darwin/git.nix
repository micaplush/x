{
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
    };

    programs.lazygit = {
      enable = true;
      settings = {
        git.autoForwardBranches = "none";
      };
    };
  };
}
