complete -c dotfiles -n "__fish_use_subcommand" -a "add" -d "Add file contents to the index"
# complete -c dotfiles -n "__fish_seen_subcommand_from add" -a "(command ls -1A)" -d "Files and directories in the current directory (including hidden)"
complete -c dotfiles -n "__fish_seen_subcommand_from add" -a "(__fish_complete_suffix)" -d "Files and directories in the current directory (including hidden)"

