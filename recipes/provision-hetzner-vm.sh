tput init

function section_start {
    tput bold
    tput setaf 2
    echo -n ":: "
    tput sgr0
    tput bold
    echo "$1"
    tput sgr0
}

function is_valid_ipv4 {
    local ip="$1"

    if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    IFS=. read -r part1 part2 part3 part4 <<< "$ip"

    if [[ "$part1" -le 0 || "$part1" -ge 255 ]]; then
        return 1
    fi
    if [[ "$part2" -le 0 || "$part2" -ge 255 ]]; then
        return 1
    fi
    if [[ "$part3" -le 0 || "$part3" -ge 255 ]]; then
        return 1
    fi
    if [[ "$part4" -le 0 || "$part4" -ge 255 ]]; then
        return 1
    fi
}

function is_private_ipv4 {
    # Taken from https://stackoverflow.com/a/13969691 and kindly translated from JavaScript to Bash by ChatGPT.

    local ip="$1"
    IFS=. read -r part1 part2 part3 part4 <<< "$ip"

    if [[ "$part1" == 10 ]]; then
        return 0
    elif [[ "$part1" == 172 && "$part2" -ge 16 && "$part2" -le 31 ]]; then
        return 0
    elif [[ "$part1" == 192 && "$part2" == 168 ]]; then
        return 0
    else
        return 1
    fi
}


section_start "Check prerequisites"

if ! hcloud server list &> /dev/null; then
    echo "error: Not able to perform basic command with Hetzner CLI"
    echo "Follow the official instructions to log in with the hcloud CLI: https://github.com/hetznercloud/cli?tab=readme-ov-file#getting-started"
    exit 1
fi

if hcloud server describe "$arg_hostname" &> /dev/null; then
    echo "error: Server named \"$arg_hostname\" exists on current Hetzner Cloud project"
    exit 1
fi

hcloud server-type describe "$arg_type" > /dev/null
hcloud location describe "$arg_location" > /dev/null


section_start "Create temp dir"

tmp_dir=$(mktemp --directory --tmpdir="$XDG_RUNTIME_DIR" vm-provisioning.XXXXXX)
readonly tmp_dir


section_start "Set up debug logging"

exec 9> "$tmp_dir/debug.log"
export BASH_XTRACEFD=9
set -x


section_start "Register cleanup code"

function cleanup {
    readonly script_exit=$?

    set +x
    exec 9>&-

    if [[ $script_exit -eq 0 ]]; then
        rm -fr "$tmp_dir"
    else
        echo
        echo "Non-zero exit code; kept temporary directory"
        echo "Clean it manually, it contains secrets!"
        echo
        echo "rm -fr $tmp_dir"
    fi
}

trap cleanup EXIT


section_start "Create needed directories"

mkdir -p "$tmp_dir/extra-files/persist/agenix"
chmod u=rwx,go= "$tmp_dir/extra-files/persist/agenix"

mkdir -p "hosts/$arg_hostname"


section_start "Generate age key"

age_key_name="key_$(date -Idate)"
readonly age_key_name

readonly age_key_file="$tmp_dir/extra-files/persist/agenix/$age_key_name"

age-keygen -o "$age_key_file"

age_pubkey=$(age-keygen -y "$age_key_file")
readonly age_pubkey


section_start "Generate host ID"

host_id=$(head -c4 /dev/urandom | od -A none -t x4 | awk '{ print $1; }')
readonly host_id


section_start "Generate host config"

nix-instantiate --eval --json \
    --argstr hostID "$host_id" \
    --argstr agenixKey "$age_key_name" \
    --argstr agenixPublicKey "$age_pubkey" \
    --argstr nixosVersion "$arg_nixos_version" \
    ./bootstrap/config-hetzner.nix \
    | jq --raw-output > "hosts/$arg_hostname/configuration.nix"


section_start "Generate secrets"

git add --intent-to-add .
just generate-secrets
just rekey-host-secrets "$arg_hostname"
git add --intent-to-add .


section_start "Request and sign Tailscale auth key"

auth_key=$(tailscale-get-authkey -client-id "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-id" -client-secret "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-secret")
readonly auth_key

readonly auth_key_file="$tmp_dir/extra-files/persist/tailscale-auth-key"

echo "Signing auth key, this will require root"
# shellcheck disable=SC2024
sudo tailscale lock sign "$auth_key" > "$auth_key_file"
chmod u=r,go= "$auth_key_file"


section_start "Generate temporary SSH key for installing NixOS"

ssh-keygen -t ed25519 -f "$tmp_dir/provisioning-ssh-key" -C "" -P "" -q
hcloud ssh-key delete auto-provisioning || true
hcloud ssh-key create --name auto-provisioning --public-key-from-file "$tmp_dir/provisioning-ssh-key.pub"


section_start "Provision VM with Ubuntu"

server_data=$(hcloud server create \
    --name "$arg_hostname" \
    --type "$arg_type" \
    --location "$arg_location" \
    --image ubuntu-24.04 \
    --ssh-key auto-provisioning \
    --output json)

readonly server_data

ip_address=$(jq --raw-output <<< "$server_data" .server.public_net.ipv4.ip)
readonly ip_address

if ! is_valid_ipv4 "$ip_address"; then
    echo "error: Server IP address obtained using hcloud CLI is not valid: $ip_address"
    exit 1
fi

if is_private_ipv4 "$ip_address"; then
    echo "error: Server IP address obtained using hcloud CLI is in a private range: $ip_address"
    exit 1
fi


section_start "Install NixOS"

nixos-anywhere --flake ".#$arg_hostname" --extra-files "$tmp_dir/extra-files" -i "$tmp_dir/provisioning-ssh-key" "root@$ip_address"
