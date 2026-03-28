{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/zfs.nix
    ../../modules/smb.nix
    ../../modules/nfs.nix
    # ../../modules/ftp.nix
    # ../../modules/telegram.nix
    # ../../modules/smart.nix
    # ../../modules/k3s.nix
  ];

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

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
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

  environment.systemPackages = with pkgs; [ git ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 524288000; # 500MiB

  # Automatic cleanup — keep only the last 5 generations, run GC weekly
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  # mdadm notifications — set to no-op until telegram.nix is enabled
  # TODO: change to "PROGRAM /etc/telegram-alert" after sops is set up
  boot.swraid.mdadmConf = "PROGRAM /bin/true";

  # sops-nix: age key derived from SSH host key (auto-available after first boot)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  system.stateVersion = "25.11";
}
