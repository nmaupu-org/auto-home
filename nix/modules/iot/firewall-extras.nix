{ pkgs, lib, ... }:

{
  # Emulated Hue + Roku (home-assistant)
  # 80: Hue/Roku API, 8060: Roku, 5540: Matter (matterbridge)
  networking.firewall.allowedTCPPorts = [ 8060 80 ];
  networking.firewall.allowedUDPPorts = [ 8060 80 5540 ];
}
