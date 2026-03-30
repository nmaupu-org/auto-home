{ config, lib, pkgs, ... }:

# Common baseline for all NixOS hosts:
# - shared packages including update-system script (flake target is configurable)
# - nix settings (flakes, GC, optimise)
# - sops age key from SSH host key
#
# Usage — set the flake target in the host configuration:
#   services.base.flakeTarget = "iot";

{
  options.services.base.flakeTarget = lib.mkOption {
    type        = lib.types.str;
    description = "Flake target name used by the update-system script (e.g. nas, iot)";
  };

  config = {
    environment.variables.EDITOR = "vim";

    environment.systemPackages = with pkgs; [
      age
      git
      inetutils
      jq
      k9s
      kubectl
      sops
      ssh-to-age
      tree
      vim
      zsh
      (writeShellScriptBin "update-system" ''
        set -e
        cd /home/nmaupu/auto-home
        git fetch --all
        git reset --hard origin/master
        sudo nixos-rebuild switch --flake ./nix#${config.services.base.flakeTarget}
      '')
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.download-buffer-size = 524288000; # 500MiB

    nix.gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    nix.settings.auto-optimise-store = true;

    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Clone auto-home repo on first boot if not already present
    systemd.services.clone-auto-home = {
      description = "Clone auto-home repository";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "!/home/nmaupu/auto-home";
      serviceConfig = {
        Type            = "oneshot";
        User            = "nmaupu";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.git}/bin/git clone https://github.com/nmaupu-org/auto-home.git /home/nmaupu/auto-home
      '';
    };
  };
}
