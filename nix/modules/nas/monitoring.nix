{ config, pkgs, ... }:

# Read-only monitoring dashboards:
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

  networking.firewall.allowedTCPPorts = [ 19999 8080 ];
}
