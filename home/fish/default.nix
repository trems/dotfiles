{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
let
  fishFiles = "${dotfiles}/home/fish/fish";
in
{
  programs.fish = {
    enable = true;
    functions = {
    };
    interactiveShellInit = ''
      fish_vi_key_bindings
    '';
  };

  xdg.configFile."fish/functions/fish_prompt.fish".source =
    mkMutableSymlink "${fishFiles}/functions/fish_prompt.fish";

}
