{ config, lib, pkgs, ... }:

# Used by the printer to upload scans to /tank/ftp_home/printer.
# Plain FTP — no TLS needed (printer doesn't support it).
#
# Note: path uses /tank/... (no altroot) — verify after `zpool import tank`.
#
# The printer user password is managed via sops-nix (ftp_user_password).
# Until sops is in place, set manually: passwd printer

{
  services.vsftpd = {
    enable = true;

    # No anonymous access
    anonymousUser = false;
    localUsers    = true;

    # Chroot local users to their home directory
    chrootlocalUser = true;

    # Allow writes
    writeEnable = true;

    extraConfig = ''
      ftpd_banner=Welcome to nas FTP
      max_clients=10
      max_per_ip=10
      idle_session_timeout=600
      data_connection_timeout=300
      pasv_enable=YES
      pasv_min_port=5000
      pasv_max_port=5020
      userlist_enable=YES
      userlist_deny=NO
      userlist_file=/etc/vsftpd/userlist
      allow_writeable_chroot=YES
      # nmaupu is exempt from chroot (gets full filesystem access)
      chroot_list_enable=YES
      chroot_list_file=/etc/vsftpd/chroot_exceptions
    '';
  };

  # Allowed users list
  environment.etc."vsftpd/userlist".text = ''
    printer
    nmaupu
    bicou
  '';

  # Users exempt from chroot (full filesystem access)
  environment.etc."vsftpd/chroot_exceptions".text = ''
    nmaupu
  '';

  networking.firewall.allowedTCPPorts = [ 21 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 5000; to = 5020; }
  ];

  users.users.printer = {
    isSystemUser = true;
    uid   = 1003;
    group = "printer";
    home  = "/tank/ftp_home";
    # Password managed via sops-nix (ftp_user_password)
  };
  users.groups.printer = { gid = 1003; };
}
