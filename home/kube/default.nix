{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  home.packages = with pkgs; [
    kubectl
    kubelogin-oidc
  ];
}
