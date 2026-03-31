{ config, lib, pkgs, ... }:

# Read-only monitoring dashboards:
#   Homepage — http://nas.home.fossar.net:8082   (services index)
#   Netdata  — http://nas.home.fossar.net:19999  (live system metrics, ZFS, SMB, NFS)
#   Scrutiny — http://nas.home.fossar.net:8080   (SMART disk health history)

{
  imports = [ ../shared/netdata.nix ];

  services.netdata.config.registry = {
    "registry to announce" = "https://mon.knas.home.fossar.net";
  };

  # Scrutiny — SMART health dashboard
  services.scrutiny = {
    enable = true;
    collector.enable = true;
    settings.web.listen.port = 8080;
  };

  # Homepage — local services dashboard (http://nas.home.fossar.net:8082)
  services.homepage-dashboard = {
    enable = true;
    settings = {
      title = "NAS";
      base  = "http://nas.home.fossar.net:8082";
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
          {
            "Headlamp" = {
              href        = "https://headlamp.knas.home.fossar.net";
              description = "Kubernetes dashboard";
              icon        = "kubernetes.png";
            };
          }
        ];
      }
    ];
  };

  # Override the NixOS module's hardcoded localhost-only allowed hosts
  systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS = lib.mkForce
    "localhost:8082,127.0.0.1:8082,nas.home.fossar.net:8082,192.168.12.8:8082";

  networking.firewall.allowedTCPPorts = [ 19999 8080 8082 ];
}
