{ ... }:

# Monitoring for iot node:
#   Netdata — http://iot.home.fossar.net:19999  (live system metrics)

{
  imports = [ ../shared/netdata.nix ];

  services.netdata.config.registry = {
    "registry to announce" = "https://mon.iot.home.fossar.net";
  };

  networking.firewall.allowedTCPPorts = [ 19999 ];
}
