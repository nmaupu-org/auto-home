{ config, lib, pkgs, ... }:

# Disk health monitoring via smartd, alerts sent via /etc/telegram-alert.
# Requires telegram.nix to be imported.

{
  services.smartd = {
    enable = true;

    # Monitor all detected drives automatically
    autodetect = true;

    defaults = {
      enable = true;
      # -o on        : enable automatic offline data collection
      # -S on        : enable automatic attribute autosave
      # -n standby,q : skip tests if drive is in standby (quiet)
      # -s ...       : short self-test daily at 02:00, long test every Saturday at 03:00
      # -m root      : required placeholder recipient when using -M exec
      # -M exec      : call our Telegram alert script instead of sendmail
      extraOptions = "-o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -m root -M exec /etc/telegram-alert";
    };

    notifications = {
      mail.enable = false;
      wall.enable = false;
    };
  };
}
