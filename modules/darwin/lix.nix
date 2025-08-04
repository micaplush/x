{
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
}
