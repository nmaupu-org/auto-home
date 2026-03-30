{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override { withCloudUi = true; };
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
    };
  };
}
