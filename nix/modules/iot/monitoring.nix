{ lib, pkgs, ... }:

# Monitoring for iot node:
#   Netdata — http://iot.home.fossar.net:19999  (live system metrics)

{
  nixpkgs.config.allowUnfree = true;
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override { withCloudUi = true; };
    config = {
      global = {
        "memory mode" = "ram";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 19999 ];
}
