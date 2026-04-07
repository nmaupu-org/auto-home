{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/shared/telegram.nix
    ../../modules/shared/update-system.nix
    ../../modules/shared/base.nix
    ../../modules/shared/k3s.nix
    ../../modules/shared/zsh.nix
    ../../modules/iot/udev.nix
    ../../modules/iot/monitoring.nix
    ../../modules/shared/ssh.nix
    ../../modules/shared/tailscale.nix
    ../../modules/iot/firewall-extras.nix
  ];

  users-shared.sopsFile = ../../secrets/iot.yaml;
  services.tailscale-config.sopsFile = ../../secrets/iot.yaml;

  services.base.flakeTarget = "iot";
  services.zsh-config.sshSymbol    = "󰋜 ";
  services.zsh-config.hostnameStyle = "bold yellow";

  # Use latest kernel to benefit from fixes in cgroup/overlayfs/containerd paths
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader — systemd-boot (single EFI disk, no mirror needed)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # LVM2 support in initrd
  boot.initrd.luks.devices = {};
  boot.initrd.services.lvm.enable = true;

  # Networking — DHCP, static lease on OpenWrt router for MAC 68:1d:ef:33:f8:33
  networking.hostName = "iot";
  networking.domain = "home.fossar.net";
  networking.networkmanager.enable = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # MOTD
  environment.interactiveShellInit = ''
    if [ -x /etc/update-motd.d/00-iot ]; then
      /etc/update-motd.d/00-iot
    fi
  '';

  environment.etc."update-motd.d/00-iot" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      echo ""
      echo " ██╗ ██████╗ ████████╗"
      echo " ██║██╔═══██╗╚══██╔══╝"
      echo " ██║██║   ██║   ██║   "
      echo " ██║██║   ██║   ██║   "
      echo " ██║╚██████╔╝   ██║   "
      echo " ╚═╝ ╚═════╝    ╚═╝   "
      echo ""

      IP=$(${pkgs.iproute2}/bin/ip -4 addr show scope global | ${pkgs.gawk}/bin/awk '/inet/{print $2}' | head -1)
      echo "  NixOS IoT  —  $(hostname -f)  ($IP)"
      echo ""
      echo "  Uptime  : $(${pkgs.procps}/bin/uptime -p)"
      echo "  Load    : $(${pkgs.coreutils}/bin/cut -d' ' -f1-3 /proc/loadavg)"
      echo ""
      echo "  k3s     : $(${pkgs.systemd}/bin/systemctl is-active k3s)"
      echo ""

      LAST_UPDATE=$(${pkgs.systemd}/bin/systemctl show update-system --property=ExecMainExitTimestamp --value 2>/dev/null)
      echo "  Last update-system: ''${LAST_UPDATE:-unknown}"
      echo ""

      echo "  Useful commands:"
      echo "    update-system          pull latest config and rebuild"
      echo "    journalctl -u k3s -f   follow k3s logs"
      echo "    k9s                    kubernetes TUI"
      echo ""
    '';
  };

  services.telegram-alert.sopsFile = ../../secrets/iot.yaml;

  # k3s — disable built-ins replaced by ArgoCD-managed equivalents
  services.k3s-node.disabledComponents = [ "traefik" "servicelb" "local-storage" ];

  services.update-system = {
    enable     = false;
    hostName   = "iot";
    hcPingUUID = "d6782ebb-66f6-47e4-a028-04131bbc1750";
  };

  system.stateVersion = "25.11";
}
