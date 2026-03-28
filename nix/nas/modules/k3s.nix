{ config, lib, pkgs, ... }:

# Single-node k3s cluster.
#
# Built-in traefik, servicelb and local-storage are disabled — they are
# replaced by TrueCharts-deployed equivalents managed by ArgoCD:
#   - traefik        → TrueCharts traefik chart
#   - servicelb      → metallb
#   - local-storage  → openEBS ZFS
#
# openEBS ZFS StorageClass must reference pool "tank" and parent dataset
# "tank/openebs-zfs" (already exists on the pool — do not recreate).
#
# ArgoCD bootstrap (Phase 5 — run once after k3s is up):
#   1. Wait for k3s:  systemctl is-active k3s
#   2. Install ArgoCD via Helm:
#        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
#        helm repo add truecharts https://charts.truecharts.org
#        helm install argocd truecharts/argocd --namespace argocd --create-namespace
#   3. Point ArgoCD at your GitOps repo and let it reconcile the rest.

{
  # k3s requires a fixed hostname and a stable hostId — both set in
  # configuration.nix and zfs.nix respectively.
  services.k3s = {
    enable = true;
    role   = "server";
    extraFlags = toString [
      "--disable traefik"
      "--disable servicelb"
      "--disable local-storage"
    ];
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
}
