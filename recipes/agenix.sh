AGENIX_KEY=${AGENIX_KEY:-}

function _agenix {
    EDITOR="${AGENIX_EDITOR:-nano -L}" agenix --identity "$1" "${@:2}"
}

# Remove preceding `secrets/` before second argument which is commonly the secret's file path
if [[ "$#" -ge 2 ]]; then
    set -- "${@:1:1}" "${2/#secrets\//}" "${@:3}"
fi

cd secrets

if [[ -z "$AGENIX_KEY" ]]; then
    # No explicit keyfile is set - use a default location for the current OS
    case "$OSTYPE" in
        darwin*)
            # On macOS, we read the key from the default keychain
            _agenix <(security find-generic-password -s nixnet-agenix-admin-key -w) "$@"
            ;;
        *)
            # On Linux, we read it from a location that is likely an in-memory FS
            # Could be improved to talk to the keyring daemon instead
            _agenix "$XDG_RUNTIME_DIR/agenix-key-nixnet" "$@"
            ;;
    esac
else
    # If we have an explicit keyfile, use that
    _agenix "$AGENIX_KEY" "$@"
fi
