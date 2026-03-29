{ config, lib, pkgs, ... }:

# Disk health monitoring via smartd, alerts sent via /etc/telegram-alert.
# Requires telegram.nix to be imported.
#
# Drives monitored:
#   tank    — 4× Seagate ST8000VN004
#   dls-tmp — 2× WD Red WD20EFRX
#   boot    — 2× Verbatim Vi550 S3 SSD

let
  # Common options for all drives:
  # -a           : all default checks
  # -o on        : enable automatic offline data collection
  # -S on        : enable automatic attribute autosave
  # -n standby,q : skip tests if drive is in standby
  # -s ...       : short test daily at 02:00, long test every Saturday at 03:00
  # -m root      : required placeholder when using -M exec
  # -M exec      : call Telegram alert script
  commonOpts = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -m root -M exec /etc/telegram-alert";

  mkDevice = id: { device = "/dev/disk/by-id/${id}"; options = commonOpts; };
in
{
  services.smartd = {
    enable = true;
    autodetect = false;

    devices = map mkDevice [
      # tank — Seagate 8TB raidz2
      "ata-ST8000VN004-3CP101_WRQ2HCAN"
      "ata-ST8000VN004-3CP101_WWZ5711R"
      "ata-ST8000VN004-3CP101_WWZ5QLQ6"
      "ata-ST8000VN004-3CP101_WWZ5VT0V"
      # dls-tmp — WD Red 2TB mirror
      "ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2585040"
      "ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2658965"
      # boot SSDs — Verbatim Vi550
      "ata-Verbatim_Vi550_S3_493504108891827"
      "ata-Verbatim_Vi550_S3_493504108891828"
    ];

    notifications = {
      mail.enable = false;
      wall.enable = false;
    };
  };
}
