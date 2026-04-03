{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/nas/zfs.nix
    ../../modules/nas/smb.nix
    ../../modules/nas/nfs.nix
    ../../modules/nas/ftp.nix
    ../../modules/shared/telegram.nix
    ../../modules/shared/update-system.nix
    ../../modules/nas/smart.nix
    ../../modules/shared/k3s.nix
    ../../modules/nas/telegram-bot.nix
    ../../modules/shared/zsh.nix
    ../../modules/shared/base.nix
    ../../modules/nas/monitoring.nix
  ];

  users-shared.sopsFile = ../../secrets/nas.yaml;

  services.base.flakeTarget = "nas";
  services.zsh-config.sshSymbol    = "󰋊 ";
  services.zsh-config.hostnameStyle = "bold cyan";

  # Bootloader — GRUB with mirrored EFI on both Verbatim SSDs
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable     = true;
    efiSupport = true;
    mirroredBoots = [
      {
        devices = [ "nodev" ];
        path    = "/boot";
      }
      {
        devices = [ "nodev" ];
        path    = "/boot-fallback";
      }
    ];
  };

  # Networking
  networking.hostName = "nas";
  networking.domain = "home.fossar.net";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 32400 ]; # plex

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings.PermitRootLogin = "yes";
  # Run dynamic motd script on interactive shell login
  environment.interactiveShellInit = ''
    if [ -x /etc/update-motd.d/00-nas ]; then
      /etc/update-motd.d/00-nas
    fi
  '';

  users.users.bicou = {
    isSystemUser       = true;
    uid                = 1002;
    group              = "bicou";
    home               = "/tank/home/bicou";
    shell              = pkgs.shadow;  # no login shell
    hashedPasswordFile = config.sops.secrets.bicou_user_password.path;
  };

  users.groups.bicou = { gid = 1002; };

  sops.secrets.bicou_user_password = {
    sopsFile      = ../../secrets/nas.yaml;
    neededForUsers = true;
  };

  services.update-system = {
    enable     = false;
    hostName   = "nas";
    hcPingUUID = "0b248bd0-a4e8-47d3-b2d9-697db7623d48";
  };

  # mdadm notifications via Telegram
  boot.swraid.mdadmConf = "PROGRAM /etc/telegram-alert";

  services.telegram-alert.sopsFile = ../../secrets/nas.yaml;

  # k3s — disable built-ins replaced by ArgoCD-managed equivalents
  services.k3s-node.disabledComponents = [ "traefik" "servicelb" "local-storage" ];

  # Dynamic MOTD via update-motd.d (no static motd set)
  environment.etc."update-motd.d/00-nas" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash

      echo ""
      echo " ███╗   ██╗ █████╗ ███████╗"
      echo " ████╗  ██║██╔══██╗██╔════╝"
      echo " ██╔██╗ ██║███████║███████╗"
      echo " ██║╚██╗██║██╔══██║╚════██║"
      echo " ██║ ╚████║██║  ██║███████║"
      echo " ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝"
      echo ""

      IP=$(${pkgs.iproute2}/bin/ip -4 addr show scope global | ${pkgs.gawk}/bin/awk '/inet/{print $2}' | head -1)
      echo "  NixOS NAS  —  $(hostname -f)  ($IP)"
      echo ""

      echo "  Uptime  : $(${pkgs.procps}/bin/uptime -p)"
      echo "  Load    : $(${pkgs.coreutils}/bin/cut -d' ' -f1-3 /proc/loadavg)"
      echo ""

      echo "  ZFS pools:"
      ${pkgs.zfs}/bin/zpool list -o name,size,alloc,free,health | ${pkgs.gawk}/bin/awk 'NR>1{printf "    %-12s  size=%-8s  alloc=%-8s  free=%-8s  %s\n",$1,$2,$3,$4,$5}'
      echo ""

      echo "  k3s     : $(${pkgs.systemd}/bin/systemctl is-active k3s)"
      echo ""

      LAST_UPDATE=$(${pkgs.systemd}/bin/journalctl -u update-system --no-pager -n 1 --output=short 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1, $2, $3}')
      echo "  Last update-system: ''${LAST_UPDATE:-unknown}"
      echo ""

      echo "  Useful commands:"
      echo "    update-system          pull latest config and rebuild"
      echo "    journalctl -u k3s -f   follow k3s logs"
      echo "    k9s                    kubernetes TUI"
      echo ""
    '';
  };

  system.stateVersion = "25.11";
}
