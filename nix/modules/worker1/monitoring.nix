{ ... }:

# Monitoring for worker1 node:
#   Netdata — http://mon.worker1.home.fossar.net:19999  (live system metrics)

{
  imports = [ ../shared/netdata.nix ];

  services.netdata.config.registry = {
    "registry to announce" = "https://mon.worker1.home.fossar.net";
  };

  networking.firewall.allowedTCPPorts = [ 19999 ];
}
