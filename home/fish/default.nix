{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}: let
  fishFiles = "${dotfiles}/home/fish/fish";
in {
  home.shell.enableFishIntegration = true;

  programs.fish = {
    enable = true;
    functions = {
      envsource = ''
        for line in (cat $argv | grep -v '^#')
            set item (string split -m 1 '=' $line)
            set -gx $item[1] $item[2]
            echo "Exported key $item[1]"
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
