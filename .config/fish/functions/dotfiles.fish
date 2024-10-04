function dotfiles --wraps='git' --description 'alias config git --git-dir=/Users/msharashin/.my_config/ --work-tree=/Users/msharashin'
    DOTFILES=1 git --git-dir=/Users/msharashin/.dotfiles/ --work-tree=/Users/msharashin $argv

end
