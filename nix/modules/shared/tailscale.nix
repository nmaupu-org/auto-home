{ config, lib, ... }:

# Usage — in the host configuration:
#   services.tailscale-config.sopsFile = ../../secrets/bastion.yaml;
#
# The secrets file must contain: tailscale_auth_key
# Generate a reusable auth key at: Tailscale admin console → Settings → Keys

{
  options.services.tailscale-config.sopsFile = lib.mkOption {
    type        = lib.types.path;
    description = "sops-encrypted secrets file containing tailscale_auth_key";
  };

  config = {
    sops.secrets.tailscale_auth_key = {
      sopsFile = config.services.tailscale-config.sopsFile;
    };

    services.tailscale = {
      enable      = true;
      authKeyFile = config.sops.secrets.tailscale_auth_key.path;
    };

    networking.firewall = {
      enable           = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts  = [ 22 ];
      allowedUDPPorts  = [ config.services.tailscale.port ];
    };
  };
}
