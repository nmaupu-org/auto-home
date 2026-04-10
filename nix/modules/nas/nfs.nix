{ config, lib, pkgs, constants, ... }:

# Note: path uses /tank/... (no altroot) — verify after `zpool import tank`.

{
  services.nfs.server = {
    enable = true;
    exports = ''
      /tank/backup-home-servers/bastion ${constants.network.lan}(rw,sec=sys,no_root_squash,insecure,no_subtree_check) ${constants.network.k3sPodCidr}(rw,sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/backup-home-servers/iot ${constants.network.lan}(rw,sec=sys,no_root_squash,insecure,no_subtree_check) ${constants.network.k3sPodCidr}(rw,sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/backup-home-servers/nas ${constants.network.lan}(rw,sec=sys,no_root_squash,insecure,no_subtree_check) ${constants.network.k3sPodCidr}(rw,sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/le-certs ${constants.network.lan}(rw,sec=sys,no_root_squash,insecure,no_subtree_check)
      /tank/k8s ${constants.network.lan}(rw,sec=sys,no_root_squash,insecure,no_subtree_check) ${constants.network.k3sPodCidr}(rw,sec=sys,no_root_squash,insecure,no_subtree_check)
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
  networking.firewall.allowedUDPPorts = [ 2049 ];
}
