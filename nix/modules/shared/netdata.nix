{ pkgs, nixpkgs-unstable, ... }:

let
  unstable = import nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; config.allowUnfree = true; };
in
{
  nixpkgs.config.allowUnfree = true;
  services.netdata = {
    enable = true;
    package = unstable.netdata.override { withCloudUi = true; };
    config = {
      global = {
        # dbengine stores metrics on disk at /var/cache/netdata
        # Sizing: ~2000 metrics * 1 byte/s * 86400 s/day * 90 days / ~10x compression ≈ 1.5 GB
        # Using 6144 MB to cover ~3 months with headroom
        "memory mode" = "dbengine";
      };
      db = {
        "dbengine multihost disk space MB" = "6144";
      };
      web = {
        # Trust connections from anywhere (Traefik proxies requests from its pod IP)
        "allow connections from" = "*";
      };
      cloud = {
        "enabled" = "no";
      };
    };
  };
}
