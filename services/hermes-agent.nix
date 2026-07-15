{config, pkgs, inputs, ...}: {
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.hostUsers = [ "mike" ];
    addToSystemPackages = true;
    package = inputs.hermes-agent.packages.${pkgs.system}.messaging;
    environmentFiles = [ config.age.secrets.hermes-env.path ];
    settings = {
      model = {
        provider = "openai-codex";
      };
    };
  };
}
