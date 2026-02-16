{
  config,
  pkgs,
  ...
}: let
  vmPort = 8428;
  nodeExporterPort = 9100;
in {
  services.victoriametrics = {
    enable = true;
    retentionPeriod = "14d";
    listenAddress = ":${toString vmPort}";
    # basicAuthUsername = "odmen";
    # basicAuthPasswordFile = agenix....;
    prometheusConfig = {
      global = {
        scrape_interval = "60s";
      };
      scrape_configs = [
        {
          job_name = "node";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = ["home-laptop2:${toString nodeExporterPort}"];
              labels.type = "node";
            }
          ];
        }
        # {
        #   job_name = "blocky";
        #   metrics_path = config.services.blocky.settings.prometheus.path;
        #   static_configs = [
        #     {targets = ["home-laptop2:${toString config.services.blocky.settings.ports.http}"];}
        #   ];
        # }
      ];
    };
  };

  services.grafana = {
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "VictoriaMetrics";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString vmPort}";
            isDefault = true;
          }
        ];
        deleteDatasources = [];
      };
      dashboards = {
        settings = {
          apiVersion = 1;
          providers = [
            {
              name = "My dashboards";
              disableDeletion = false;
              options = {
                path = "/etc/grafana/dashboards";
                foldersFromFilesStructure = true;
              };
            }
          ];
        };
      };
    };
    declarativePlugins = with pkgs.grafanaPlugins; [
      # victoriametrics-metrics-datasource
      # victoriametrics-logs-datasource
    ];
  };
  services.prometheus.exporters.node = {
    enable = true;
    port = nodeExporterPort;
    enabledCollectors = ["systemd"];
  };
  environment.etc."grafana/dashboards".source = ./dashboards;
}
