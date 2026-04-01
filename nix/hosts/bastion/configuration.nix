{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/shared/base.nix
    ../../modules/shared/zsh.nix
  ];

  services.base.flakeTarget = "bastion";
  services.zsh-config.sshSymbol    = " ";
  services.zsh-config.hostnameStyle = "bold green";

  # RPi4 bootloader (managed by nixos-hardware module)
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Networking — DHCP, static lease on router for MAC dc:a6:32:54:73:91
  networking.hostName = "bastion";
  networking.domain = "home.fossar.net";
  networking.useDHCP = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH — port 22 open on LAN; Tailscale provides secure remote path
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Tailscale
  services.tailscale.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  users-shared.sopsFile = ../../secrets/bastion.yaml;

  # Users
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.root_password.path;
  };

  sops.secrets.root_password = {
    sopsFile       = ../../secrets/bastion.yaml;
    neededForUsers = true;
  };

  # Auto-update
  systemd.services.update-system = {
    description = "Auto-update NixOS system configuration";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      ${pkgs.git}/bin/git config --global --add safe.directory /home/nmaupu/auto-home
      cd /home/nmaupu/auto-home
      ${pkgs.git}/bin/git fetch --all
      ${pkgs.git}/bin/git reset --hard origin/master
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix#bastion
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
