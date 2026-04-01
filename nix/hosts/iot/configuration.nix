{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/shared/telegram.nix
    ../../modules/shared/base.nix
    ../../modules/shared/k3s.nix
    ../../modules/shared/zsh.nix
    ../../modules/iot/udev.nix
    ../../modules/iot/monitoring.nix
  ];

  users-shared.sopsFile = ../../secrets/iot.yaml;

  services.base.flakeTarget = "iot";
  services.zsh-config.sshSymbol    = "󰋜 ";
  services.zsh-config.hostnameStyle = "bold yellow";

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

  # SSH
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings.PermitRootLogin = "yes";

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
      echo "  ███╗   ██╗██╗██╗  ██╗██╗ ██████╗ ████████╗"
      echo "  ████╗  ██║██║╚██╗██╔╝██║██╔═══██╗╚══██╔══╝"
      echo "  ██╔██╗ ██║██║ ╚███╔╝ ██║██║   ██║   ██║   "
      echo "  ██║╚██╗██║██║ ██╔██╗ ██║██║   ██║   ██║   "
      echo "  ██║ ╚████║██║██╔╝ ██╗██║╚██████╔╝   ██║   "
      echo "  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝    ╚═╝   "
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

  # Auto-update
  systemd.services.update-system = {
    description = "Auto-update NixOS system configuration";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    unitConfig.OnFailure = "update-system-failure@%n.service";
    script = ''
      cd /root/auto-home
      ${pkgs.git}/bin/git fetch --all
      ${pkgs.git}/bin/git reset --hard origin/master
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix#iot
      ${pkgs.curl}/bin/curl -fsS --retry 3 https://hc-ping.com/d6782ebb-66f6-47e4-a028-04131bbc1750 > /dev/null
    '';
  };

  systemd.services."update-system-failure@" = {
    description = "Notify Telegram on update-system failure";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      /etc/telegram-alert "IoT update-system failed — check: journalctl -u update-system"
    '';
  };

  systemd.timers.update-system = {
    description = "Daily NixOS system update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent  = true;
    };
  };

  system.stateVersion = "25.11";
}
