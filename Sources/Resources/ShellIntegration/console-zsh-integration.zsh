# Console.app shell integration for zsh
# Injected via ZDOTDIR — do not source manually

# ── Restore the user's original ZDOTDIR ──────────────────────────────────────
if [[ -n "${CONSOLE_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$CONSOLE_ZSH_ZDOTDIR"
    builtin unset CONSOLE_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

# Source the user's .zshrc
builtin typeset _console_user_rc="${ZDOTDIR-$HOME}/.zshrc"
[[ ! -r "$_console_user_rc" ]] || builtin source -- "$_console_user_rc"
builtin unset _console_user_rc

# ── OSC 7: notify Console.app whenever the working directory changes ─────────
# Pure-zsh percent encoding (no python3 dependency)
_console_urlencode_path() {
    local input="$1" i char hex encoded=""
    for (( i=0; i < ${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            [a-zA-Z0-9/_.-~]) encoded+="$char" ;;
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

autoload -U add-zsh-hook
add-zsh-hook chpwd _console_notify_cwd
_console_notify_cwd   # emit immediately on startup

# ── Shift+Enter: insert a literal newline without executing ──────────────────
_console_insert_newline() {
    LBUFFER+=$'\n'
}
zle -N _console_insert_newline
bindkey '\e[13;2u' _console_insert_newline
