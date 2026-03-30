{ config, lib, pkgs, ... }:

# Shared single-node k3s cluster module.
#
# Usage — set disabled components in the host configuration:
#   services.k3s-node.disabledComponents = [ "traefik" "servicelb" "local-storage" ];
#
# Firewall ports (6443, 10250, 8472/udp) are always opened.

{
  options.services.k3s-node.disabledComponents = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = "Built-in k3s components to disable (e.g. traefik, servicelb, local-storage)";
  };

  config = {
    services.k3s = {
      enable = true;
      role   = "server";
      extraFlags = toString (
        map (c: "--disable ${c}") config.services.k3s-node.disabledComponents
      );
    };

    # k3s bundles containerd; make sure the kernel has the required modules.
    boot.kernelModules = [ "br_netfilter" "overlay" ];

    # Firewall — NixOS merges these with ports from other modules automatically
    networking.firewall.allowedTCPPorts = [
      6443   # k3s API server (kubectl + ArgoCD agent)
      10250  # kubelet metrics
    ];
    networking.firewall.allowedUDPPorts = [
      8472   # Flannel VXLAN
    ];

    # Copy k3s kubeconfig to nmaupu's ~/.kube/conf.d/ after k3s starts
    # so that kubectl works without sudo for the nmaupu user.
    systemd.services.k3s-kubeconfig = {
      description = "Copy k3s kubeconfig for nmaupu";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -o nmaupu -g nmaupu /home/nmaupu/.kube
        install -m 0600 -o nmaupu -g nmaupu \
          /etc/rancher/k3s/k3s.yaml \
          /home/nmaupu/.kube/config
      '';
    };
  };
}
