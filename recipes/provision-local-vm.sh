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


section_start "Check prerequisites"

if ! [[ "$arg_vcpu" =~ ^[0-9]+$ ]]; then
    echo "vCPU count must be an integer number"
    exit 1
fi

if [[ "$arg_vcpu" -lt 1 || "$arg_vcpu" -gt 16 ]]; then
    echo "vCPU count must be between 1 and 16 (both inclusive)"
    exit 1
fi

if ! [[ "$arg_memory" =~ ^[0-9]+$ ]]; then
    echo "Memory must be given as integer number of megabytes"
    exit 1
fi

readonly memory_min=512
readonly memory_max=$((32*1024))
if [[ "$arg_memory" -lt $memory_min || "$arg_memory" -gt $memory_max ]]; then
    echo "Memory must be between $memory_min and $memory_max (both inclusive)"
    exit 1
fi

if ! [[ "$arg_disk_size" =~ ^[0-9]+$ ]]; then
    echo "Disk size must be given as integer number of gigabytes"
    exit 1
fi

readonly disk_size_min=20
readonly disk_size_max=$((8*1024))
if [[ "$arg_disk_size" -lt $disk_size_min || "$arg_disk_size" -gt $disk_size_max ]]; then
    echo "Disk size must be between $disk_size_min and $disk_size_max (both inclusive)"
    exit 1
fi

if [[ -e "hosts/$arg_hostname" ]]; then
    echo "error: Config for host $arg_hostname already exists"
    echo "Move, delete, or deactivate it before provisioning a new VM under that name"
    exit 1
fi

readonly disk_file="/var/lib/libvirt/images/$arg_hostname.raw"
if ssh root@minis test -e "$disk_file"; then
    echo "error: Disk for host $arg_hostname already exists at $disk_file"
    echo "Delete the existing disk before provisioning a new VM under that name"
    exit 1
fi


section_start "Create temp dirs"

tmp_dir=$(mktemp --directory --tmpdir="$XDG_RUNTIME_DIR" vm-provisioning.XXXXXX)
readonly tmp_dir

remote_tmp_dir=$(ssh root@minis mktemp --directory --tmpdir='$XDG_RUNTIME_DIR' vm-provisioning.XXXXXX)
readonly remote_tmp_dir


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
        ssh root@minis rm -r "$remote_tmp_dir"
    else
        echo
        echo "Non-zero exit code; kept temporary directories"
        echo "Clean these up manually, they contain secrets!"
        echo
        echo "rm -r $tmp_dir"
        echo "ssh root@minis rm -r $remote_tmp_dir"
    fi
}

trap cleanup EXIT


section_start "Generate age key"

age_key_name="key_$(date -Idate)"
readonly age_key_name

age-keygen -o "$tmp_dir/age-key"

age_pubkey=$(age-keygen -y "$tmp_dir/age-key")
readonly age_pubkey


section_start "Generate host ID"

host_id=$(head -c4 /dev/urandom | od -A none -t x4 | awk '{ print $1; }')
readonly host_id


section_start "Generate MAC address"

mac_address=$(printf '02:00:00:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))


section_start "Generate domain config"

mkdir -p domainconfigs "hosts/$arg_hostname"

nix-instantiate --eval --json \
    --argstr hostname "$arg_hostname" \
    --argstr macAddress "$mac_address" \
    --argstr memory "$arg_memory" \
    --argstr vcpu "$arg_vcpu" \
    ./bootstrap/domainconfig.nix \
    | jq --raw-output > "domainconfigs/$arg_hostname.xml"


section_start "Generate host config"

nix-instantiate --eval --json \
    --argstr hostID "$host_id" \
    --argstr agenixKey "$age_key_name" \
    --argstr agenixPublicKey "$age_pubkey" \
    --argstr diskSize "${arg_disk_size}G" \
    --argstr nixosVersion "$arg_nixos_version" \
    ./bootstrap/config-local.nix \
    | jq --raw-output > "hosts/$arg_hostname/configuration.nix"


section_start "Generate secrets"

git add --intent-to-add .
just generate-secrets
just rekey-host-secrets "$arg_hostname"
git add --intent-to-add .


section_start "Build and copy disko image creation script"

nix build --out-link "$tmp_dir/disko-image" .#nixosConfigurations."$arg_hostname".config.system.build.diskoImagesScript
image_script_store_path=$(realpath "$tmp_dir/disko-image")
readonly image_script_store_path

nix copy --to ssh://root@minis "$image_script_store_path"


section_start "Request and sign Tailscale auth key"

auth_key=$(tailscale-get-authkey -client-id "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-id" -client-secret "$XDG_RUNTIME_DIR/tailscale-get-authkey-client-secret")
readonly auth_key

echo "Signing auth key, this will require root"
# shellcheck disable=SC2024
sudo tailscale lock sign "$auth_key" > "$tmp_dir/tailscale-signed-authkey"


section_start "Copy age key to hypervisor"

rsync "$tmp_dir/age-key" root@minis:"$remote_tmp_dir/"
# shellcheck disable=SC2029
ssh root@minis chmod u=r,go= "$remote_tmp_dir/age-key"


section_start "Copy domain config to hypervisor"

rsync "domainconfigs/$arg_hostname.xml" root@minis:"$remote_tmp_dir/domainconfig.xml"


section_start "Copy Tailscale auth key to hypervisor"

rsync "$tmp_dir/tailscale-signed-authkey" root@minis:"$remote_tmp_dir/"
# shellcheck disable=SC2029
ssh root@minis chmod u=r,go= "$remote_tmp_dir/tailscale-signed-authkey"


section_start "Build actual disk image on hypervisor"

# shellcheck disable=SC2029
ssh root@minis "$image_script_store_path" \
    --build-memory 4096 \
    --post-format-files "$remote_tmp_dir/age-key" "/persist/agenix/$age_key_name" \
    --post-format-files "$remote_tmp_dir/tailscale-signed-authkey" /persist/tailscale-auth-key \
    > "$tmp_dir/disk-image-build-out.log" \
    2> "$tmp_dir/disk-image-build-err.log"


section_start "Move disk image to libvirt storage location"

# shellcheck disable=SC2029
ssh root@minis mv main.raw "/var/lib/libvirt/images/$arg_hostname.raw"


section_start "Register domain with libvirt"

# shellcheck disable=SC2029
ssh root@minis virsh define "$remote_tmp_dir/domainconfig.xml"