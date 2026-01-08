{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}: let
  fishFiles = "${dotfiles}/home/fish/fish";
in {
  xdg.configFile."fish/functions/fish_prompt.fish".source =
    mkMutableSymlink "${fishFiles}/functions/fish_prompt.fish";

  home.shell.enableFishIntegration = true;

  programs.fish = {
    enable = true;
    functions = {
      envsource = ''
        if not test -f $argv[1]
            echo "envsource: file '$argv[1]' does not exist or is not a regular file." >&2
            exit 1
        end

        for line in (cat $argv[1] | grep -v '^#')
            set item (string split -m 1 '=' $line)
            if test (count $item) -ge 2
                set -gx $item[1] $item[2]
                echo "Exported key $item[1]"
            else
                echo "Warning: Skipping invalid line: '$line'" >&2
            end
        end
      '';
    };
    interactiveShellInit = ''
      fish_vi_key_bindings
      envsource ~/.env
      npm config set prefix '~/npm-packages' && fish_add_path '~/npm-packages/bin' && set -U NODE_PATH ~/.npm-packages/lib/node_modules
    '';
    shellAliases = {
      v = "nvim";
    };
  };
}
