{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/users.nix
    ../../modules/shared/telegram.nix
    ../../modules/shared/update-system.nix
    ../../modules/shared/base.nix
    ../../modules/shared/ssh.nix
    ../../modules/shared/tailscale.nix
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


  users-shared.sopsFile = ../../secrets/bastion.yaml;
  services.tailscale-config.sopsFile = ../../secrets/bastion.yaml;
  services.telegram-alert.sopsFile = ../../secrets/bastion.yaml;

  # Users
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.root_password.path;
  };

  sops.secrets.root_password = {
    sopsFile       = ../../secrets/bastion.yaml;
    neededForUsers = true;
  };

  services.update-system = {
    enable     = false;
    hostName   = "bastion";
    hcPingUUID = "0b197972-4024-49c7-8f47-4b4c2ee8b1aa";
  };

  system.stateVersion = "25.11";
}
