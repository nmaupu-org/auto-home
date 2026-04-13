{ config, lib, pkgs, ... }:

{
  # Required by ZFS — must be unique per machine.
  # Generate with: head -c 8 /etc/machine-id
  networking.hostId = "c65240e3";

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Data pools (boot SSD is handled by the bootloader, not listed here)
  boot.zfs.extraPools = [ "tank" "dls-tmp" ];

  fileSystems."/var/lib/longhorn" = {
    device = "/dev/zvol/tank/longhorn";
    fsType = "ext4";
  };

  # ZED — ZFS event daemon, alerts via Telegram on pool errors/scrub results
  services.zfs.zed = {
    enableMail = false;
    settings = {
      ZED_DEBUG_LOG       = "/tmp/zed.debug.log";
      ZED_NOTIFY_VERBOSE  = 1;  # also notify on scrub completion (not just errors)
      ZED_NOTIFY_DATA     = 1;
      ZED_RUN_SPARES      = 0;
      ZED_EMAIL_PROG      = "/etc/telegram-alert";
      ZED_EMAIL_OPTS      = "@ADDRESS@";
    };
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # autotrim is off on the pool (spinning disks); keeping it disabled.
  services.zfs.trim.enable = false;

  # openEBS ZFS plugin runs in a chroot and expects zfs/zpool at standard paths.
  # On NixOS binaries live in the Nix store, so we expose them via /usr/local/bin.
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin/zfs  - - - - ${pkgs.zfs}/bin/zfs"
    "L+ /usr/local/bin/zpool - - - - ${pkgs.zfs}/bin/zpool"
  ];

  services.sanoid = {
    enable = true;

    datasets = {
      "tank/home" = {
        hourly  = 24;
        daily   = 30;
        weekly  = 8;
        monthly = 6;
        autosnap  = true;
        autoprune = true;
      };
      "tank/docs" = {
        hourly  = 24;
        daily   = 30;
        weekly  = 8;
        monthly = 6;
        autosnap  = true;
        autoprune = true;
      };
      "tank/photos" = {
        hourly  = 0;
        daily   = 0;
        weekly  = 52;
        monthly = 0;
        autosnap  = true;
        autoprune = true;
      };
      "tank/backup-mac-air" = {
        hourly  = 0;
        daily   = 30;
        weekly  = 8;
        monthly = 6;
        autosnap  = true;
        autoprune = true;
      };
      "tank/backup-mac-pro-bicou" = {
        hourly  = 0;
        daily   = 30;
        weekly  = 8;
        monthly = 6;
        autosnap  = true;
        autoprune = true;
      };
      "tank/ftp_home" = {
        hourly  = 24;
        daily   = 30;
        weekly  = 4;
        monthly = 3;
        autosnap  = true;
        autoprune = true;
      };
      "tank/vault-nas" = {
        hourly  = 24;
        daily   = 30;
        weekly  = 8;
        monthly = 6;
        autosnap  = true;
        autoprune = true;
      };
      "tank/backup-home-servers" = {
        hourly     = 0;
        daily      = 90;
        weekly     = 0;
        monthly    = 0;
        autosnap   = true;
        autoprune  = true;
        recursive  = true;
      };
    };
  };
}
