AGENIX_KEY=${AGENIX_KEY:-}

function generate_secrets {
    secrets-generator -config ./result -identity "$1"
}

nix build ".#secretsGenerationConfig.$arg_nix_system"

if [[ -z "$AGENIX_KEY" ]]; then
    # No explicit keyfile is set - use a default location for the current OS
    case "$OSTYPE" in
        darwin*)
            # On macOS, we read the key from the default keychain
            generate_secrets <(security find-generic-password -s nixnet-agenix-admin-key -w)
            ;;
        *)
            # On Linux, we read it from a location that is likely an in-memory FS
            # Could be improved to talk to the keyring daemon instead
            generate_secrets "$XDG_RUNTIME_DIR/agenix-key-nixnet"
            ;;
    esac
else
    # If we have an explicit keyfile, use that
    generate_secrets "$AGENIX_KEY"
fi
