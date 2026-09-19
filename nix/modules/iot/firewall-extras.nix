{ pkgs, lib, ... }:

{
  # Emulated Hue + Roku (home-assistant, runs with hostNetwork so these must be
  # open on EVERY node it can be scheduled on)
  # 80: Hue/Roku API, 8060: Roku, 5540: Matter (matterbridge), 8283: matterbridge web UI; 8123 home assistant
  # 1900/udp: SSDP multicast discovery (emulated_roku is found by the Harmony Hub through it)
  networking.firewall.allowedTCPPorts = [ 8060 80 8283 8123 ];
  networking.firewall.allowedUDPPorts = [ 8060 80 5540 1900 ];
}
