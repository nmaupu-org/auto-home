{ ... }:

# Udev rules for Zigbee USB coordinators.
# - Sonoff Zigbee 3.0 USB Dongle Plus (cp210x, serial: 5c1d7030e96aef11aa58a4adc169b110)
# - Zazah CH341 adapter (ch341-uart, no unique serial — matched by vid:pid only)

{
  services.udev.extraRules = ''
    ACTION=="add", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="5c1d7030e96aef11aa58a4adc169b110", SYMLINK+="sonoff_coord_xiaomi"
    ACTION=="add", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="zazah_coord_misc"
  '';
}
