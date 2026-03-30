{ ... }:

# Monitoring for iot node:
#   Netdata — http://iot.home.fossar.net:19999  (live system metrics)

{
  imports = [ ../shared/netdata.nix ];

  networking.firewall.allowedTCPPorts = [ 19999 ];
}
