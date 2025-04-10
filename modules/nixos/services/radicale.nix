{ config, globalConfig, lib, pkgs, ... }:

let
  cfg = config.x.services.radicale;

  localPort = config.x.base.localport.ports.radicale;
  storageDir = "${config.x.base.filesystems.persistDirectory}/radicale";
in
{
  options.x.services.radicale = {
    enable = lib.mkEnableOption "Radicale";
  };

  config = lib.mkIf cfg.enable {
    x.base.localport.decls.radicale = { };

    x.global.agenix.secrets = lib.mkMerge [
      {
        "radicale/htpasswd" = {
          generation.template = {
            data.users = globalConfig.radicale.users;
            content = ''
              {{- range .users -}}
              {{ . }}:{{ hashBcrypt (readSecret (fmt "radicale/passwords/%s" .)) 10 }}
              {{ end -}}
            '';
          };
        };
      }

      (lib.pipe globalConfig.radicale.users [
        (builtins.map (username: {
          name = "radicale/passwords/${username}";
          value = {
            generation.random = { };
          };
        }))
        lib.listToAttrs
      ])
    ];

    x.global.agenix.secretMounts."radicale/htpasswd" = {
      owner = config.users.users.radicale.name;
      group = config.users.users.radicale.group;
    };

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = [ "127.0.0.1:${builtins.toString localPort}" ];

        auth = {
          type = "htpasswd";
          htpasswd_filename = globalConfig.agenix.secretMounts."radicale/htpasswd".path;
          htpasswd_encryption = "bcrypt";
        };

        storage = {
          filesystem_folder = storageDir;
          hook =
            let
              gitignore = builtins.toFile "radicale-collection-gitignore" ''
                .Radicale.cache
                .Radicale.lock
                .Radicale.tmp-*
              '';

              authorName = "Radicale";
              authorEmail = "radicale@in.tbx.at";

              hookScript = pkgs.writeShellApplication {
                name = "radicale-git-hook";
                runtimeInputs = [ pkgs.git ];
                text = ''
                  readonly username="$1"

                  export GIT_AUTHOR_NAME=${authorName}
                  export GIT_AUTHOR_EMAIL=${authorEmail}
                  export GIT_COMMITTER_NAME=${authorName}
                  export GIT_COMMITTER_EMAIL=${authorEmail}

                  if [[ ! -e .git ]]; then
                    git init --initial-branch main
                  fi

                  cat ${gitignore} > .gitignore
                  git add .gitignore
                  if ! git diff --cached --quiet; then
                    git commit --message "Update .gitignore"
                  fi

                  git add .
                  if ! git diff --cached --quiet; then
                    git commit --message "Changes by $username"
                  fi
                '';
              };
            in
            "${lib.getExe hookScript} %(user)s";
        };
      };
    };

    systemd.services.radicale = {
      after = [ "tailscale-up.service" ];
      requires = [ "tailscale-up.service" ];
    };

    x.server.caddy.services.radicale.extraConfig = ''
      reverse_proxy 127.0.0.1:${builtins.toString localPort}
    '';

    system.activationScripts.radicale-persistent-dir.text = ''
      mkdir -p ${storageDir}
      chown ${config.users.users.radicale.name}:${config.users.users.radicale.group} ${storageDir}
      chmod u=rwx,go= ${storageDir}
    '';
  };
}
