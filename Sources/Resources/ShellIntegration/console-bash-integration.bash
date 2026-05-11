# Console.app shell integration for bash
# Injected via --rcfile — do not source manually

# ── Source the user's .bashrc ────────────────────────────────────────────────
if [[ -r "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
fi

# ── OSC 7: notify Console.app whenever the working directory changes ─────────
# Pure-bash percent encoding (no python3 dependency)
_console_urlencode_path() {
    local input="$1" i char hex encoded=""
    for (( i=0; i < ${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            [a-zA-Z0-9/_.\~-]) encoded+="$char" ;;
            *) printf -v hex '%%%02X' "'$char"
               encoded+="$hex" ;;
        esac
    done
    printf '%s' "$encoded"
}

_console_notify_cwd() {
    local encoded_path
    encoded_path=$(_console_urlencode_path "$PWD")
    printf '\033]7;file://localhost%s\033\\' "$encoded_path"
}

# Use PROMPT_COMMAND to emit OSC 7 before each prompt
if [[ -z "$_CONSOLE_PROMPT_INSTALLED" ]]; then
    _CONSOLE_PROMPT_INSTALLED=1
    PROMPT_COMMAND="_console_notify_cwd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

_console_notify_cwd   # emit immediately on startup
