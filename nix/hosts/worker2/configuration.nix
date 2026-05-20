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
    ../../modules/worker2/monitoring.nix
    # iot replacement: USB Zigbee udev rules + extra firewall ports (HA / Roku / Matter)
    ../../modules/iot/udev.nix
    ../../modules/iot/firewall-extras.nix
  ];

  users-shared.sopsFile = ../../secrets/worker2.yaml;
  services.tailscale-config.sopsFile = ../../secrets/worker2.yaml;

  services.base.flakeTarget = "worker2";
  services.zsh-config.sshSymbol    = "󰒋 ";
  services.zsh-config.hostnameStyle = "bold green";

  # Bootloader — systemd-boot (single EFI disk)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # LVM2 support in initrd
  boot.initrd.luks.devices = {};
  boot.initrd.services.lvm.enable = true;

  # Networking — DHCP (no static lease yet; MAC TBD, will take over iot's
  # 192.168.12.40 once iot is decommissioned)
  networking.hostName = "worker2";
  networking.domain = "home.fossar.net";
  networking.networkmanager.enable = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # MOTD
  environment.interactiveShellInit = ''
    if [ -x /etc/update-motd.d/00-worker2 ]; then
      /etc/update-motd.d/00-worker2
    fi
  '';

  environment.etc."update-motd.d/00-worker2" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      echo ""
      echo " ██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗███████╗██████╗     ██████╗ "
      echo " ██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██╔════╝██╔══██╗    ╚════██╗"
      echo " ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ █████╗  ██████╔╝     █████╔╝"
      echo " ██║███╗██║██║   ██║██╔══██╗██╔═██╗ ██╔══╝  ██╔══██╗    ██╔═══╝ "
      echo " ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗███████╗██║  ██║    ███████╗"
      echo "  ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚══════╝"
      echo ""

      IP=$(${pkgs.iproute2}/bin/ip -4 addr show scope global | ${pkgs.gawk}/bin/awk '/inet/{print $2}' | head -1)
      echo "  NixOS Worker2  —  $(hostname -f)  ($IP)"
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

  services.telegram-alert.sopsFile = ../../secrets/worker2.yaml;

  # k3s — iot replacement: same labels as iot, USB devices + iot workloads pinned here.
  # No taint (matches iot's previous behavior — other workloads can still float here).
  services.k3s-node = {
    role      = "agent";
    serverUrl = "https://${constants.hosts.nasIp}:6443";
    tokenFile = config.sops.secrets.k3s_cluster_token.path;
    nodeLabels = [ "role=iot" ];
  };

  sops.secrets.k3s_cluster_token = {
    sopsFile = ../../secrets/worker2.yaml;
  };

  services.update-system = {
    enable     = true;
    hostName   = "worker2";
    # hcPingUUID = "<healthchecks.io UUID — set once the check is created>";
  };

  system.stateVersion = "25.11";
}
