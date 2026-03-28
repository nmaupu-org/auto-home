{ config, lib, pkgs, ... }:

{
  # Required by ZFS — must be unique per machine.
  # Generate with: head -c 8 /etc/machine-id
  networking.hostId = "c65240e3";

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Data pools (boot SSD is handled by the bootloader, not listed here)
  boot.zfs.extraPools = [ "tank" "dls-tmp" ];

  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # autotrim is off on the pool (spinning disks); keeping it disabled.
  services.zfs.trim.enable = false;

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
    };
  };
}
