{ deps, lib, pkgs, ... }:

let
  installer = pkgs.writeShellApplication {
    name = "pve-installer";

    runtimeInputs = with pkgs; [
      dosfstools
      e2fsprogs
      nix
      nixos-install-tools
      util-linux

      deps.disko.packages.x86_64-linux.disko
    ];

    text = ''
      set -x
      disko --mode destroy,format,mount --yes-wipe-all-disks ${./disko.nix}

      mkdir /mnt/persist/agenix
      chown -R root:root /mnt/persist/agenix
      chmod u=rwx,go= /mnt/persist/agenix
      cp /installer-bundle/key_* /mnt/persist/agenix/
      chmod u=r,go= /mnt/persist/agenix/key_*

      cp /installer-bundle/tailscale-auth-key /mnt/persist/
      chown root:root /mnt/persist/tailscale-auth-key
      chmod u=rw,go= /mnt/persist/tailscale-auth-key

      nix-store --store /mnt --import < /installer-bundle/closure
      nixos-install --system "$(cat /installer-bundle/system)" --no-root-password
      systemctl poweroff
    '';
  };

  installerFailsafe = pkgs.writeShellScript "pve-installer-failsafe" ''
    ${lib.getExe installer} || echo "ERROR: Installation failure!"
    sleep infinity
  '';
in
{
  boot.kernelParams = [ "console=ttyS0,115200n8" ];

  boot.supportedFilesystems.virtiofs = true;

  isoImage.squashfsCompression = "zstd -Xcompression-level 15"; # xz takes forever
  system.nixos.tags = [ "autoinstall" ];

  fileSystems."/installer-bundle" = {
    fsType = "virtiofs";
    device = "nixos-install";
  };

  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      ExecStart = [ "" installerFailsafe ];
      Restart = "no";
      StandardInput = "null";
    };

    after = [ "installer-bundle.mount" ];
    wants = [ "installer-bundle.mount" ];
  };

  services.getty.autologinUser = "root";

  system.stateVersion = lib.trivial.release;
}
