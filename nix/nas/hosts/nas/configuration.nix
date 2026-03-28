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
    ../../modules/telegram-bot.nix
    ../../modules/zsh.nix
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
    isNormalUser       = true;
    uid                = 1001;
    group              = "nmaupu";
    extraGroups        = [ "wheel" ];
    shell              = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets.nmaupu_user_password.path;
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAuxw5aDJj7SuXLRQS1bWpzKrvXOYv9Ts23gDzHdDvF nmaupu@nmaupu-laptop" ];
  };

  users.groups.nmaupu = { gid = 1001; };

  security.sudo.extraRules = [{
    users = [ "nmaupu" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  users.users.bicou = {
    isSystemUser       = true;
    uid                = 1002;
    group              = "bicou";
    home               = "/tank/home/bicou";
    shell              = pkgs.shadow;  # no login shell
    hashedPasswordFile = config.sops.secrets.bicou_user_password.path;
  };

  users.groups.bicou = { gid = 1002; };

  sops.secrets.nmaupu_user_password = {
    sopsFile      = ../../secrets/secrets.yaml;
    neededForUsers = true;
  };
  sops.secrets.bicou_user_password = {
    sopsFile      = ../../secrets/secrets.yaml;
    neededForUsers = true;
  };

  systemd.services.update-system = {
    description = "Auto-update NixOS system configuration";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      cd /home/nmaupu/auto-home
      ${pkgs.git}/bin/git fetch --all
      ${pkgs.git}/bin/git reset --hard origin/master
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix/nas#nas
    '';
  };

  systemd.timers.update-system = {
    description = "Hourly NixOS system update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent  = true;
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    jq
    zsh
    sops
    age
    ssh-to-age
    k9s
    kubectl
    (writeShellScriptBin "update-system" ''
      set -e
      cd /home/nmaupu/auto-home
      git fetch --all
      git reset --hard origin/master
      sudo nixos-rebuild switch --flake ./nix/nas#nas
    '')
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 524288000; # 500MiB

  # Automatic cleanup — keep only the last 5 generations, run GC weekly
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  # mdadm notifications via Telegram
  boot.swraid.mdadmConf = "PROGRAM /etc/telegram-alert";

  # sops-nix: age key derived from SSH host key (auto-available after first boot)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  system.stateVersion = "25.11";
}
