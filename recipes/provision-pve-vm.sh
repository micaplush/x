# Shellcheck check SC2029 is disabled for some lines.
# It warns that variables in SSH commands are expanded on the client side.
# In all of the cases where the check is disabled, that's what we want.


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


FOXMOX_HOST=fox01


section_start "Check prerequisites"

if [[ -e "clients/nixos/$arg_hostname" ]]; then
    echo "error: Config for host $arg_hostname already exists"
    echo "Move, delete, or deactivate it before provisioning a new VM under that name"
    exit 1
fi


section_start "Create temp dirs"

tmp_dir=$(mktemp --directory --tmpdir=/tmp nixos-vm-provisioning.XXXXXX)
readonly tmp_dir

remote_tmp_dir=$(ssh $FOXMOX_HOST mktemp --directory --tmpdir='$XDG_RUNTIME_DIR' nixos-vm-provisioning.XXXXXX)
readonly remote_tmp_dir

mkdir "$tmp_dir/installer-bundle"


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
        rm -r "$tmp_dir"

        # shellcheck disable=SC2029
        ssh $FOXMOX_HOST rm -r "$remote_tmp_dir"
    else
        echo
        echo "Non-zero exit code; kept temporary directories"
        echo "Clean these up manually, they contain secrets!"
        echo
        echo "rm -r $tmp_dir"
        echo "ssh $FOXMOX_HOST rm -r $remote_tmp_dir"
    fi
}

trap cleanup EXIT


section_start "Generate age key"

age_key_name="key_$(date -Idate)"
readonly age_key_name

age-keygen -o "$tmp_dir/installer-bundle/$age_key_name"

age_pubkey=$(age-keygen -y "$tmp_dir/installer-bundle/$age_key_name")
readonly age_pubkey


section_start "Generate host ID"

host_id=$(head -c4 /dev/urandom | od -A none -t x4 | awk '{ print $1; }')
readonly host_id


section_start "Generate host config"

mkdir -p "clients/nixos/$arg_hostname"

nix-instantiate --eval --json \
    --argstr hostID "$host_id" \
    --argstr agenixKey "$age_key_name" \
    --argstr agenixPublicKey "$age_pubkey" \
    --argstr nixosVersion "$arg_nixos_version" \
    ./bootstrap/config-pve.nix \
    | jq --raw-output > "clients/nixos/$arg_hostname/configuration.nix"


section_start "Generate secrets"

git add --intent-to-add .
just generate-secrets
just rekey-host-secrets "$arg_hostname"
git add --intent-to-add .


section_start "Build system config"

nix build --out-link "$tmp_dir/system" .#nixosConfigurations."$arg_hostname".config.system.build.toplevel
system_store_path=$(realpath "$tmp_dir/system")
readonly system_store_path

echo "$system_store_path" > "$tmp_dir/installer-bundle/system"


section_start "Export closure to installer bundle"

nix-store --query --requisites "$tmp_dir/system" | xargs nix-store --export > "$tmp_dir/installer-bundle/closure"


section_start "Request and sign Tailscale auth key"

auth_key=$(tailscale-get-authkey -client-id "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-id" -client-secret "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-secret")
readonly auth_key

echo "Signing auth key"
# shellcheck disable=SC2024
tailscale lock sign "$auth_key" > "$tmp_dir/installer-bundle/tailscale-auth-key"


section_start "Upload installer bundle"

# shellcheck disable=SC2029
ssh $FOXMOX_HOST mkdir "$remote_tmp_dir/installer-bundle"
# shellcheck disable=SC2029
ssh $FOXMOX_HOST chmod u=rwx,go= "$remote_tmp_dir/installer-bundle"

rsync -r "$tmp_dir/installer-bundle/" $FOXMOX_HOST:"$remote_tmp_dir/installer-bundle"


section_start "Move installer bundle to virtio directory"

# shellcheck disable=SC2029
ssh -t $FOXMOX_HOST su --login --command "\"rsync -r $remote_tmp_dir/installer-bundle/ /var/lib/virtiofs-nixos-install/\""

echo
echo
tput bold
echo "Done! Next, boot the VM"
echo "After installation, clear out the installer bundle"
tput sgr0
echo
echo "ssh -t fox01 su --login --command \"'rm -f /var/lib/virtiofs-nixos-install/*'\""