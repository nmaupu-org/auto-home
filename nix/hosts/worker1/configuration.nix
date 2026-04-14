{ config, pkgs, lib, constants, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/shared/telegram.nix
    ../../modules/shared/update-system.nix
    ../../modules/shared/base.nix
    ../../modules/shared/k3s.nix
    ../../modules/shared/zsh.nix
    ../../modules/shared/ssh.nix
    ../../modules/shared/tailscale.nix
    ../../modules/worker1/monitoring.nix
  ];

  users-shared.sopsFile = ../../secrets/worker1.yaml;
  services.tailscale-config.sopsFile = ../../secrets/worker1.yaml;

  services.base.flakeTarget = "worker1";
  services.zsh-config.sshSymbol    = "󰒋 ";
  services.zsh-config.hostnameStyle = "bold green";

  # Bootloader — systemd-boot (single EFI disk)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # LVM2 support in initrd
  boot.initrd.luks.devices = {};
  boot.initrd.services.lvm.enable = true;

  # Networking — DHCP, static lease on OpenWrt router for MAC TBD → 192.168.12.41
  networking.hostName = "worker1";
  networking.domain = "home.fossar.net";
  networking.networkmanager.enable = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # MOTD
  environment.interactiveShellInit = ''
    if [ -x /etc/update-motd.d/00-worker1 ]; then
      /etc/update-motd.d/00-worker1
    fi
  '';

  environment.etc."update-motd.d/00-worker1" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      echo ""
      echo " ██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗███████╗██████╗      ██╗"
      echo " ██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██╔════╝██╔══██╗    ███║"
      echo " ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ █████╗  ██████╔╝    ╚██║"
      echo " ██║███╗██║██║   ██║██╔══██╗██╔═██╗ ██╔══╝  ██╔══██╗     ██║"
      echo " ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗███████╗██║  ██║     ██║"
      echo "  ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝     ╚═╝"
      echo ""

      IP=$(${pkgs.iproute2}/bin/ip -4 addr show scope global | ${pkgs.gawk}/bin/awk '/inet/{print $2}' | head -1)
      echo "  NixOS Worker1  —  $(hostname -f)  ($IP)"
      echo ""
      echo "  Uptime  : $(${pkgs.procps}/bin/uptime -p)"
      echo "  Load    : $(${pkgs.coreutils}/bin/cut -d' ' -f1-3 /proc/loadavg)"
      echo ""
      echo "  k3s     : $(${pkgs.systemd}/bin/systemctl is-active k3s)"
      echo ""

      LAST_UPDATE=$(${pkgs.systemd}/bin/systemctl show update-system --property=ExecMainExitTimestamp --value 2>/dev/null)
      echo "  Last update-system: ''${LAST_UPDATE:-unknown}"
    '';
  };

  services.telegram-alert.sopsFile = ../../secrets/worker1.yaml;

  # k3s — floating agent node, no taint (general workloads land here by default)
  services.k3s-node = {
    role      = "agent";
    serverUrl = "https://${constants.hosts.nasIp}:6443";
    tokenFile = config.sops.secrets.k3s_cluster_token.path;
    nodeLabels = [ "role=worker" ];
    # no nodeTaints — this node accepts any workload
  };

  sops.secrets.k3s_cluster_token = {
    sopsFile = ../../secrets/worker1.yaml;
  };

  services.update-system = {
    enable     = true;
    hostName   = "worker1";
    hcPingUUID = "d54df01a-0e7d-4bb4-b578-ffb3b5f8b30c";
  };

  system.stateVersion = "25.11";
}
