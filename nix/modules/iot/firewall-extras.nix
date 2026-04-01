{ pkgs, lib, ... }:

{
  # Emulated Hue + Roku (home-assistant)
  networking.firewall.allowedTCPPorts = [ 8060 80 ];
  networking.firewall.allowedUDPPorts = [ 8060 80 ];
}
