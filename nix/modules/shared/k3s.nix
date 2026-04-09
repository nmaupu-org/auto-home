{ config, lib, pkgs, ... }:

# Shared k3s cluster module — supports both server and agent roles.
#
# Usage in host configuration:
#
#   Server (control plane + worker):
#     services.k3s-node = {
#       role       = "server";   # default
#       tokenFile  = config.sops.secrets.k3s_cluster_token.path;
#       nodeLabels = [ "role=nas" ];
#       nodeTaints = [ "role=nas:NoSchedule" ];
#       disabledComponents = [ "traefik" "servicelb" "local-storage" ];
#     };
#
#   Agent:
#     services.k3s-node = {
#       role      = "agent";
#       serverUrl = "https://192.168.12.8:6443";
#       tokenFile = config.sops.secrets.k3s_cluster_token.path;
#       nodeLabels = [ "role=iot" ];
#       nodeTaints = [ "role=iot:NoSchedule" ];
#     };
#
# Firewall ports (6443, 10250, 8472/udp) are always opened.

let
  cfg = config.services.k3s-node;
in
{
  options.services.k3s-node = {
    role = lib.mkOption {
      type        = lib.types.enum [ "server" "agent" ];
      default     = "server";
      description = "k3s node role: server (control plane) or agent (worker only)";
    };

    serverUrl = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "For agent nodes: URL of the k3s server (e.g. https://192.168.12.8:6443)";
    };

    tokenFile = lib.mkOption {
      type        = lib.types.nullOr lib.types.path;
      default     = null;
      description = "Path to file containing the cluster join token (sops-managed). Required for agents; recommended for server to ensure a stable token.";
    };

    nodeLabels = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Node labels to apply at startup (e.g. [ \"role=nas\" ])";
    };

    nodeTaints = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Node taints to apply at startup (e.g. [ \"role=nas:NoSchedule\" ])";
    };

    disabledComponents = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Built-in k3s components to disable — server only (e.g. traefik, servicelb, local-storage)";
    };
  };

  config = {
    services.k3s = {
      enable    = true;
      role      = cfg.role;
      serverAddr = lib.mkIf (cfg.role == "agent") cfg.serverUrl;
      tokenFile  = lib.mkIf (cfg.tokenFile != null) cfg.tokenFile;
      extraFlags = toString (
        (lib.optionals (cfg.role == "server")
          (map (c: "--disable ${c}") cfg.disabledComponents))
        ++ (map (l: "--node-label ${l}") cfg.nodeLabels)
        ++ (map (t: "--node-taint ${t}") cfg.nodeTaints)
      );
    };

    # k3s bundles containerd; make sure the kernel has the required modules.
    boot.kernelModules = [ "br_netfilter" "overlay" ];

    # NFS client — required for k8s pods that mount NFS volumes directly.
    boot.supportedFilesystems = [ "nfs" ];

    # Firewall — NixOS merges these with ports from other modules automatically
    networking.firewall.allowedTCPPorts = [
      6443   # k3s API server (kubectl + agent join)
      10250  # kubelet metrics
    ];
    networking.firewall.allowedUDPPorts = [
      8472   # Flannel VXLAN
    ];

    # Copy k3s kubeconfig to nmaupu's ~/.kube/config after k3s starts.
    # On agent nodes the kubeconfig isn't generated — the service is a no-op.
    systemd.services.k3s-kubeconfig = {
      description = "Copy k3s kubeconfig for nmaupu";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        [ -f /etc/rancher/k3s/k3s.yaml ] || exit 0
        install -d -o nmaupu -g nmaupu /home/nmaupu/.kube
        install -m 0600 -o nmaupu -g nmaupu \
          /etc/rancher/k3s/k3s.yaml \
          /home/nmaupu/.kube/config
      '';
    };
  };
}
