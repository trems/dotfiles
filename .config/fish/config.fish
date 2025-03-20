if status is-interactive
    # Commands to run in interactive sessions can go here
end

switch (uname)
    case Darwin
        set -gx HOMEBREW_PREFIX /usr/local
        set -gx HOMEBREW_CELLAR /usr/local/Cellar
        set -gx HOMEBREW_REPOSITORY /usr/local/Homebrew
        fish_add_path -gP /usr/local/bin /usr/local/sbin
        ! set -q MANPATH; and set MANPATH ''
        set -gx MANPATH /usr/local/share/man $MANPATH
        ! set -q INFOPATH; and set INFOPATH ''
        set -gx INFOPATH /usr/local/share/info $INFOPATH
end

if test -x "$(which lazygit)"
    abbr --add lg lazygit
end

# Created by `pipx` on 2024-07-10 09:25:37
set PATH $PATH /Users/msharashin/.local/bin

if fish_is_in_nvim
    fish_default_key_bindings
else
    fish_vi_key_bindings
    bind -M insert -m default jj backward-char force-repaint
end

zoxide init fish | source
