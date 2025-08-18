{
  perSystem = { inputs', lib, pkgs, self', system, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        age
        hcloud
        just
        nano
        nix
        nix-tree
        shellcheck
      ];

      shellHook = ''
        source ${self'.justfiles.default.setupScript}
      '';
    };

    justfiles.default.recipes = {
      agenix = {
        args = lib.singleton {
          name = "agenix_args";
          variadic = "*";
        };

        doc = "Call agenix with some defaults";

        runtimeInputs = lib.singleton (inputs'.agenix.packages.default.override {
          ageBin = lib.getExe pkgs.age;
        });

        script = ../../recipes/agenix.sh;
      };

      build = {
        args = [ "host" ];

        doc = "Build the given host configuration";

        runtimeInputs = [ pkgs.nix ];
        script = ''
          nix build .#nixosConfigurations."$arg_host".config.system.build.toplevel
        '';
      };

      cloc = {
        args = lib.singleton {
          name = "cloc_args";
          variadic = "*";
        };

        doc = "Count lines of code";

        runtimeInputs = [ pkgs.cloc ];
        script = ''
          cloc --vcs git \
            --fullpath \
            --not-match-d 'modules/nixos/services/(?:grafana/dashboards|res/content)' \
            --not-match-f 'modules/nixos/services/grafana/alerting-rules\.yml' \
            "$@"
        '';
      };

      darwin-rebuild = {
        args = lib.singleton {
          name = "darwin-rebuild_args";
          variadic = "*";
        };

        doc = "Run darwin-rebuild on the local host";

        script = ''
          sudo darwin-rebuild --flake .# "$@"
        '';
      };

      delete-unreferenced-secrets = {
        doc = "Delete data and entropy files for secrets that are not referenced in any host config";
        script = ''
          referenced=$(nix eval .#secretsGenerationData --json | jq \
            --raw-output \
            '.secrets
              | keys
              | map("./secrets/data/\(.).age\n./secrets/entropy/\(.).age")
              | .[]
            ' | sort)

          existing=$(find ./secrets/{data,entropy} -type f -name '*.age' | sort)
          unreferenced=$(comm -13 <(echo "$referenced") <(echo "$existing"))

          if [[ -z "$unreferenced" ]]; then
            echo "No unreferened secret files"
            exit
          fi

          echo
          echo "Deleting:"
          echo
          echo "$unreferenced"
          echo
          echo -n "Proceed? [y/N] "

          read -r answer
          if ! [[ "$answer" == y || "$answer" == Y ]]; then
            echo Cancelled
            exit 1
          fi

          xargs rm <<< "$unreferenced"
        '';
      };

      deploy = {
        args = [ "host" "operation" ];

        doc = "Deploy to the given host with the given operation";

        runtimeInputs = [ pkgs.nix ];
        script = ''
          nix build --out-link result .#nixosConfigurations."$arg_host".config.system.build.toplevel
          config_store_path=$(realpath result)

          target_system=$(cat result/system)

          nix build --out-link install-nixos-config .#packages."$target_system".install-nixos-config
          install_store_path=$(realpath install-nixos-config)

          nix copy --to ssh://root@"$arg_host" "$install_store_path" "$config_store_path"

          # shellcheck disable=SC2029 # yes, those variables should expand before going over SSH
          ssh root@"$arg_host" "$install_store_path"/bin/install-nixos-config "$arg_operation" "$config_store_path"
        '';
      };

      generate-secrets = {
        args = lib.singleton { name = "nix_system"; default = system; };

        doc = "Generate all secrets that are out of date";

        runtimeInputs = [ pkgs.nix self'.packages.secrets-generator ];
        script = ../../recipes/generate-secrets.sh;
      };

      provision-local-vm = {
        args = [
          "hostname"
          "vcpu"
          "memory"
          "disk_size"
          { name = "nixos_version"; default = lib.versions.majorMinor lib.version; }
        ];

        doc = "Provision a new VM and generate a bootstrap host config";

        runtimeInputs = [
          pkgs.age
          pkgs.ncurses
          pkgs.nix
          pkgs.rsync
          self'.packages.tailscale-get-authkey
        ];

        script = ../../recipes/provision-local-vm.sh;
      };

      provision-pve-vm = {
        args = [
          "hostname"
          { name = "nixos_version"; default = lib.versions.majorMinor lib.version; }
        ];

        doc = "Provision a new VM on Foxmox and generate a bootstrap host config";

        runtimeInputs = [
          pkgs.age
          pkgs.ncurses
          pkgs.nix
          pkgs.rsync
          self'.packages.tailscale-get-authkey
        ];

        script = ../../recipes/provision-pve-vm.sh;
      };

      reboot = {
        args = [ "host" ];
        doc = "Reboot a given host";
        script = ''
          ssh "root@$arg_host" reboot
        '';
      };

      rekey-host-secrets = {
        args = [ "host" ];
        doc = "Rekey all secrets mounted on the given host";
        script = ''
          secrets=$(nix eval .#secretsGenerationData --json | jq \
            --raw-output \
            --arg host "$arg_host" \
            '.secretMounts
              | to_entries
              | map(select(.value.host == $host) | "secrets/data/\(.value.secret).age")
              | .[]
            ')

          while read -r -u 4 secret; do
            echo "Rekeying $secret..."
            AGENIX_EDITOR=: just agenix -e "$secret"
          done 4<<< "$secrets"
        '';
      };

      reload-direnv = {
        doc = "Reload direnv";
        script = ''
          direnv reload
        '';
      };

      update-tailnet-data = {
        doc = "Update IP addresses and domain name of the Tailnet";
        script = ''
          sudo tailscale status --json | jq --raw-output --sort-keys '{
              "domain": .CurrentTailnet.MagicDNSSuffix,
              "nodes": [ .Self, .Peer[] ] | map({ "key": .DNSName | split(".")[0], "value": .TailscaleIPs | map(select(contains(":") | not))[0] }) | from_entries
          }' > modules/nixos/base/tailscale/tailnet.json
        '';
      };
    };
  };
}
