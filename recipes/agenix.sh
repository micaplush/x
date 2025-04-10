AGENIX_KEY=${AGENIX_KEY:-$XDG_RUNTIME_DIR/agenix-key-nixnet}

if [[ "$#" -ge 2 ]]; then
    set -- "${@:1:1}" "${2/#secrets\//}" "${@:3}" # Remove preceding `secrets/` before second argument which is commonly the secret's file path
fi

cd secrets
EDITOR="${AGENIX_EDITOR:-nano -L}" agenix --identity "$AGENIX_KEY" "$@"
