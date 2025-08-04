{ globalConfig, lib, ... }:

{
  home-manager.users.mica = { lib, ... }: {
    programs.ssh.enable = true;

    programs.ssh.extraConfig =
      let
        hosts = lib.pipe globalConfig.netsrv.hosts [
          lib.attrNames
          (lib.filter (hostname: globalConfig.netsrv.services ? "ssh.${hostname}"))
        ];
      in
      ''
        Host github.com
            IdentityFile ~/.ssh/id_github_ed25519

        Host *.in.tbx.at,${builtins.concatStringsSep "," hosts}
            IdentityFile ~/.ssh/id_internal_ed25519

        Host *
            UseKeychain yes
            AddKeysToAgent yes
      '';
  };

  programs.ssh.knownHosts =
    let
      extraHostNames = {
        minis = [ "forge.in.tbx.at" ];
      };

      internalHosts = lib.pipe ../../secrets/derived/ssh-public-keys [
        builtins.readDir
        (lib.mapAttrs' (k: v:
          let
            hostName = "${k}.in.tbx.at";
          in
          {
            name = hostName;
            value = {
              publicKeyFile = ../../secrets/derived/ssh-public-keys/${k}/ed25519;
              hostNames = [ hostName k ] ++ (if extraHostNames ? ${k} then extraHostNames.${k} else [ ]);
            };
          }))
      ];

      foxmoxHostParams = {
        fox01 = {
          addresses = [ "192.168.7.11" ];
          publicKey = "ssh-ed25519 AAAAREDACTED";
        };
        fox02 = {
          addresses = [ "192.168.7.12" ];
          publicKey = "ssh-ed25519 AAAAREDACTED";
        };
        fox03 = {
          addresses = [ "192.168.7.13" ];
          publicKey = "ssh-ed25519 AAAAREDACTED";
        };
      };

      foxmoxHosts = lib.flip lib.mapAttrs' foxmoxHostParams
        (hostname: params: {
          name = "${hostname}.in.tbx.at";
          value = {
            inherit (params) publicKey;
            hostNames = lib.flatten [
              hostname
              "${hostname}.in.tbx.at"
              params.addresses
            ];
          };
        });

      otherHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };

      knownHosts = lib.mergeAttrsList [
        otherHosts
        foxmoxHosts
        internalHosts
      ];
    in
    knownHosts;

  launchd.agents.ssh-agent = { };
}
