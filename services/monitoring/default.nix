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
    listenAddress = ":${toString vmPort}";
    # basicAuthUsername = "odmen";
    # basicAuthPasswordFile = agenix....;
    prometheusConfig = {
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
            type = "victoriametrics-metrics-datasource";
            access = "proxy";
            url = "http://127.0.0.1:${toString vmPort}";
            isDefault = true;
          }
          # {
          #   name = "VictoriaLogs";
          #   type = "victoriametrics-logs-datasource";
          #   access = "proxy";
          #   url = "http://127.0.0.1:9428";
          #   isDefault = false;
          # }
        ];
        deleteDatasources = [];
      };
      dashboards = {
        settings = {
          apiVersion = 1;
          providers = [
            {
              name = "Overview";
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
      victoriametrics-metrics-datasource
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
