{config, pkgs, inputs, ...}: {
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.hostUsers = [ "mike" ];
    addToSystemPackages = true;
    package = inputs.hermes-agent.packages.${pkgs.system}.messaging;
    environmentFiles = [ config.age.secrets.hermes-env.path ];
    environment = {
      HTTP_PROXY = "http://127.0.0.1:1081";
      HTTPS_PROXY = "http://127.0.0.1:1081";
    };
    settings = {
      model = {
        provider = "openai-codex";
      };
    };
  };
}
