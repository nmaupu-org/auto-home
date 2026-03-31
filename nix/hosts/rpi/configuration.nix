{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared/base.nix
    ../../modules/shared/zsh.nix
  ];

  services.base.flakeTarget = "rpi";
  services.zsh-config.sshSymbol    = " ";
  services.zsh-config.hostnameStyle = "bold green";

  # RPi4 bootloader (managed by nixos-hardware module)
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Networking — DHCP, static lease on router for MAC dc:a6:32:54:73:91
  networking.hostName = "nixbastion";
  networking.domain = "home.fossar.net";
  networking.useDHCP = true;

  # Basic system
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH — no firewall opening needed (access via Tailscale only)
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
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # Users
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.root_password.path;
  };

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

  sops.secrets.root_password = {
    sopsFile       = ../../secrets/bastion.yaml;
    neededForUsers = true;
  };

  sops.secrets.nmaupu_user_password = {
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
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ./nix#rpi
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
