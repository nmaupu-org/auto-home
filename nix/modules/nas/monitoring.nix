{ config, pkgs, ... }:

# Read-only monitoring dashboards:
#   Homepage — http://nas.home.fossar.net:3000   (services index)
#   Netdata  — http://nas.home.fossar.net:19999  (live system metrics, ZFS, SMB, NFS)
#   Scrutiny — http://nas.home.fossar.net:8080   (SMART disk health history)

{
  # Netdata — real-time metrics dashboard (proprietary cloud UI enabled)
  nixpkgs.config.allowUnfree = true;
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override { withCloudUi = true; };
    config = {
      global = {
        "memory mode" = "ram";   # no persistent history, keep it lightweight
      };
    };
  };

  # Scrutiny — SMART health dashboard
  services.scrutiny = {
    enable = true;
    collector.enable = true;
    settings.web.listen.port = 8080;
  };

  # Homepage — local services dashboard (http://nas.home.fossar.net:3000)
  services.homepage-dashboard = {
    enable = true;
    settings = {
      title = "NAS";
      base  = "http://nas.home.fossar.net:3000";
    };
    services = [
      {
        "Monitoring" = [
          {
            "Netdata" = {
              href        = "http://nas.home.fossar.net:19999";
              description = "Live system metrics";
              icon        = "netdata.png";
            };
          }
          {
            "Scrutiny" = {
              href        = "http://nas.home.fossar.net:8080";
              description = "Disk SMART health";
              icon        = "scrutiny.png";
            };
          }
        ];
      }
      {
        "Kubernetes" = [
          {
            "ArgoCD" = {
              href        = "https://argocd.knas.home.fossar.net";
              description = "GitOps controller";
              icon        = "argocd.png";
            };
          }
          {
            "Vault" = {
              href        = "https://vault.knas.home.fossar.net/ui/";
              description = "Secrets management";
              icon        = "vault.png";
            };
          }
        ];
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 19999 8080 3000 ];
}
