{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/zfs.nix
    ../../modules/smb.nix
    ../../modules/nfs.nix
    ../../modules/ftp.nix
    ../../modules/telegram.nix
    ../../modules/smart.nix
    ../../modules/k3s.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nas";
  networking.networkmanager.enable = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  users.users.nmaupu = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAuxw5aDJj7SuXLRQS1bWpzKrvXOYv9Ts23gDzHdDvF nmaupu@nmaupu-laptop" ];
  };

  users.users.bicou = {
    isSystemUser = true;
    group = "bicou";
    shell = pkgs.shadow;  # no login shell
  };

  users.groups.bicou = {};

  # sops-nix: age key derived from SSH host key (auto-available after first boot)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  system.stateVersion = "25.05";
}
