{ config, lib, pkgs, ... }:

let
  nmaupu-laptop-sshkeypub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAuxw5aDJj7SuXLRQS1bWpzKrvXOYv9Ts23gDzHdDvF nmaupu@nmaupu-laptop";
  cfg = config.users-shared;
in
{
  options.users-shared.sopsFile = lib.mkOption {
    type = lib.types.path;
    description = "Path to the sops secrets file containing nmaupu_user_password";
  };

  config = {
    users.users.nmaupu = {
      isNormalUser = true;
      uid          = 1001;
      group        = "nmaupu";
      extraGroups  = [ "wheel" ];
      shell        = pkgs.zsh;
      hashedPasswordFile = config.sops.secrets.nmaupu_user_password.path;
      openssh.authorizedKeys.keys = [ nmaupu-laptop-sshkeypub ];
    };

    users.groups.nmaupu = { gid = 1001; };

    security.sudo.extraRules = [{
      users    = [ "nmaupu" ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }];

    sops.secrets.nmaupu_user_password = {
      sopsFile       = cfg.sopsFile;
      neededForUsers = true;
    };
  };
}
