# Fish shell configuration
if status is-interactive
    set -g fish_greeting ""
    starship init fish | source

    # Common aliases
    alias ls='ls --color=auto'
    alias ll='ls -lah'
    alias grep='grep --color=auto'
end
