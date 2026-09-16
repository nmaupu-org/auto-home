{ ... }:

# Udev rules for Zigbee USB coordinators.
# - Sonoff Zigbee 3.0 USB Dongle Plus (cp210x, serial: 5c1d7030e96aef11aa58a4adc169b110)
# - zig-a-zig-ah CC2652R (CH340, no unique serial). worker2 (Firebat N100) has a
#   second, onboard CH340 (bcdDevice 81.34) so vid:pid alone is ambiguous: match
#   on the stick's bcdDevice (2.64) and restrict to tty nodes so the raw USB
#   device nodes don't claim the symlink too.

{
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ACTION=="add", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="5c1d7030e96aef11aa58a4adc169b110", SYMLINK+="sonoff_coord_xiaomi"
    SUBSYSTEM=="tty", ACTION=="add", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", ATTRS{bcdDevice}=="0264", SYMLINK+="zazah_coord_misc"
  '';
}
