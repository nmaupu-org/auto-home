{ pkgs, lib, ... }:

{
  # Emulated Hue + Roku (home-assistant)
  # 80: Hue/Roku API, 8060: Roku, 5540: Matter (matterbridge), 8283: matterbridge web UI
  networking.firewall.allowedTCPPorts = [ 8060 80 8283 ];
  networking.firewall.allowedUDPPorts = [ 8060 80 5540 ];
}
