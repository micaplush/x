{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.freeradius;

  clientConfigSecret = "radius/client-config";
  userConfigSecret = "radius/user-config";

  # Test with: radtest testing foobar 127.0.0.1 0 testing456

  freeradiusConfig = pkgs.symlinkJoin {
    name = "freeradius-config";
    paths = [ pkgs.freeradius.out ];
    postBuild = ''
      cd $out/etc/raddb

      ln -sf ${globalConfig.agenix.secretMounts.${clientConfigSecret}.path} clients.conf
      ln -sf ${globalConfig.agenix.secretMounts.${userConfigSecret}.path} mods-config/files/authorize

      ln -sf ${config.x.server.acme.certs.radius.directory}/full.pem certs/server.pem
      ln -sf ${config.x.server.acme.certs.radius.directory}/chain.pem certs/ca.pem

      mv radiusd.conf radiusd.conf.1
      sed < radiusd.conf.1 -E 's/require_message_authenticator =.+$/require_message_authenticator = yes/' > radiusd.conf
      rm radiusd.conf.1
    '';
  };
in
{
  options.x.services.freeradius.enable = lib.mkEnableOption "FreeRADIUS";

  config = lib.mkIf cfg.enable {
    services.freeradius = {
      enable = true;
      configDir = "${freeradiusConfig}/etc/raddb";
    };

    # The FreeRADIUS module doesn't create a group. Instead it leaves that up to you, I guess for compatibility?
    users.users.radius.group = "radius";
    users.groups.radius = { };

    x.server.acme.certs.radius.options = {
      group = config.users.users.radius.group;
      postRun = ''
        systemctl --no-block restart freeradius.service
      '';
    };

    x.global.agenix.secrets = lib.mkMerge [
      {
        ${clientConfigSecret}.generation.template = {
          data.clients = globalConfig.radius.clients;
          content = ''
            {{ range $name, $client := .clients }}
            client {{ $name }} {
              ipaddr = {{ $client.ipaddr }}
              secret = {{ fmt "%s" (readSecret $client.secret) }}
            }
            {{ end }}
          '';
        };

        ${userConfigSecret}.generation.template = {
          data.users = globalConfig.radius.users;
          content = ''
            {{- range $name, $user := .users -}}
            {{ $name }}	Cleartext-Password := "{{ fmt "%s" (readSecret $user.passwordSecret) }}"
            {{- with $user.vlan }}
              Tunnel-Type = "VLAN",
              Tunnel-Medium-Type = "IEEE-802",
              Tunnel-Private-Group-Id = "{{ . }}"
            {{ else }}
            {{ end }}
            {{ end }}
          '';
        };
      }

      (lib.mapAttrs'
        (clientName: client: {
          name = client.secret;
          value.generation.random.charsets.special = false;
        })
        globalConfig.radius.clients)

      (lib.mapAttrs'
        (username: user: {
          name = user.passwordSecret;
          value.generation.random.charsets.special = false;
        })
        globalConfig.radius.users)
    ];

    x.global.agenix.secretMounts =
      let
        owner = config.users.users.radius.name;
        group = config.users.users.radius.group;
      in
      {
        ${clientConfigSecret} = {
          inherit owner group;
        };

        ${userConfigSecret} = {
          inherit owner group;
        };
      };

    x.global.netsrv.services.radius.ports = {
      auth = {
        port = 1812;
        protocol = "udp";
      };

      acct = {
        port = 1813;
        protocol = "udp";
      };
    };
  };
}
