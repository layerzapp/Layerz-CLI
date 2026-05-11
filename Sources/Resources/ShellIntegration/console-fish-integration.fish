# Console.app shell integration for fish
# Injected via --init-command — do not source manually

# ── OSC 7: notify Console.app whenever the working directory changes ─────────
function __console_urlencode_path
    set -l path $argv[1]
    # fish's string escape --style=url encodes the path
    string replace -a ' ' '%20' -- $path | string replace -a '#' '%23' | string replace -a '?' '%3F'
end

function __console_notify_cwd --on-variable PWD
    set -l encoded_path (printf '%s' $PWD | string replace -a ' ' '%20' | string replace -a '#' '%23' | string replace -a '?' '%3F')
    printf '\033]7;file://localhost%s\033\\' $encoded_path
end

# Emit immediately on startup
__console_notify_cwd
