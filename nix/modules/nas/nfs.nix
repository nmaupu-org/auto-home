{ config, lib, pkgs, ... }:

# Note: path uses /tank/... (no altroot) — verify after `zpool import tank`.

{
  services.nfs.server = {
    enable = true;
    exports = ''
      /tank/backup-home-servers/bastion 192.168.12.0/24(sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/backup-home-servers/iot 192.168.12.0/24(sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/backup-home-servers/nas 192.168.12.0/24(sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/le-certs 192.168.12.0/24(sec=sys,no_root_squash,insecure,no_subtree_check)
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
  networking.firewall.allowedUDPPorts = [ 2049 ];
}
