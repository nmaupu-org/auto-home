{ config, lib, pkgs, ... }:

# Used by the printer to upload scans to /tank/ftp_home/printer.
# Plain FTP — no TLS needed (printer doesn't support it).
#
# Note: path uses /tank/... (no altroot) — verify after `zpool import tank`.
#
# The ftpuser password is managed via sops-nix (ftp_user_password).
# Until sops is in place, set manually: passwd ftpuser

{
  services.proftpd = {
    enable = true;
    displayConnect = "Welcome to nas FTP";
    defaultRoot = true;

    extraConfig = ''
      ServerName              "nas"
      Port                    21
      MaxClients              10
      MaxConnectionsPerHost   10
      MaxLoginAttempts        5
      TimeoutIdle             600
      TimeoutNoTransfer       300

      PassivePorts            5000 5020

      # Local users only, no anonymous
      AuthOrder               mod_auth_unix.c
      RequireValidShell       off

      # Chroot to home directory
      DefaultRoot             ~

      # No FXP, no ident, no reverse DNS
      AllowForeignAddress     off
      IdentLookups            off
      UseReverseDNS           off

      # Umask: files=000, dirs=022
      Umask                   000 022

      # Allow resume of interrupted transfers
      AllowRetrieveRestart    on
      AllowStoreRestart       on

      # Restrict login to ftpuser only
      <Limit LOGIN>
        AllowUser ftpuser
        DenyAll
      </Limit>

    '';
  };

  networking.firewall.allowedTCPPorts = [ 21 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 5000; to = 5020; }
  ];

  users.users.ftpuser = {
    isSystemUser = true;
    group = "ftpuser";
    home = "/tank/ftp_home";
    # Password managed via sops-nix (ftp_user_password)
  };
  users.groups.ftpuser = {};
}
