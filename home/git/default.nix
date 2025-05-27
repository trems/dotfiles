{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.git = {
    enable = true;
    extraConfig = {
      core = {
        autocrlf = "input";
      };
      rebase.
      push.autoSetupRemote = true;
    };
    includes = [
      {
        # condition = "gitdir:~/work/";
        path = "${config.home.homeDirectory}/work/.gitconfig";
      }
    ];
    delta = {
      enable = true;
      options = {
        "tokyonight-moon" = {
          dark = true;
          minus-style = ''syntax "#3a273a"'';
          minus-non-emph-style = ''syntax "#3a273a"'';
          minus-emph-style = ''syntax "#6b2e43"'';
          minus-empty-line-marker-style = ''syntax "#3a273a"'';
          line-numbers-minus-style = ''"#e26a75"'';
          plus-style = ''syntax "#273849"'';
          plus-non-emph-style = ''syntax "#273849"'';
          plus-emph-style = ''syntax "#305f6f"'';
          plus-empty-line-marker-style = ''syntax "#273849"'';
          line-numbers-plus-style = ''"#b8db87"'';
          line-numbers-zero-style = ''"#3b4261"'';

        };
        navigate = true;
        line-numbers = true;
        true-color = "always";
        features = "tokyonight-moon";
      };
    };
  };

}
