root@nas:~# zpool list
NAME        SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
boot-pool   103G  7.48G  95.5G        -       15G    16%     7%  1.00x    ONLINE  -
dls-tmp    1.81T  43.8M  1.81T        -         -     1%     0%  1.00x    ONLINE  /mnt
tank       29.1T  14.2T  14.9T        -         -     5%    48%  1.00x    ONLINE  /mnt
root@nas:~# zpool status
  pool: boot-pool
 state: ONLINE
status: One or more features are enabled on the pool despite not being
        requested by the 'compatibility' property.
action: Consider setting 'compatibility' to an appropriate value, or
        adding needed features to the relevant file in
        /etc/zfs/compatibility.d or /usr/share/zfs/compatibility.d.
  scan: scrub repaired 0B in 00:01:30 with 0 errors on Tue Mar 24 03:46:31 2026
config:

        NAME        STATE     READ WRITE CKSUM
        boot-pool   ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdc3    ONLINE       0     0     0
            sdb3    ONLINE       0     0     0

errors: No known data errors

  pool: dls-tmp
 state: ONLINE
  scan: scrub repaired 0B in 00:00:12 with 0 errors on Sun Mar 22 00:00:15 2026
config:

        NAME                                      STATE     READ WRITE CKSUM
        dls-tmp                                   ONLINE       0     0     0
          mirror-0                                ONLINE       0     0     0
            sda2                                  ONLINE       0     0     0
            420f52ab-31a5-4df4-bb28-0fccc06062bf  ONLINE       0     0     0

errors: No known data errors

  pool: tank
 state: ONLINE
  scan: scrub repaired 0B in 07:39:32 with 0 errors on Sun Mar 22 07:39:46 2026
config:

        NAME        STATE     READ WRITE CKSUM
        tank        ONLINE       0     0     0
          raidz2-0  ONLINE       0     0     0
            sdh2    ONLINE       0     0     0
            sdg2    ONLINE       0     0     0
            sde2    ONLINE       0     0     0
            sdf2    ONLINE       0     0     0

errors: No known data errors

---


root@nas:~# zfs list -r
NAME                                                                  USED  AVAIL  REFER  MOUNTPOINT
boot-pool                                                            7.48G  92.3G    24K  none
boot-pool/.system                                                    1.94M  92.3G    28K  legacy
boot-pool/.system/configs-cadb1ce96f8c4a01a65be3ef8f5cb996             24K  92.3G    24K  legacy
boot-pool/.system/cores                                               500K  1024M   500K  legacy
boot-pool/.system/rrd-cadb1ce96f8c4a01a65be3ef8f5cb996               1.25M  92.3G  1.25M  legacy
boot-pool/.system/samba4                                             43.5K  92.3G  43.5K  legacy
boot-pool/.system/services                                             24K  92.3G    24K  legacy
boot-pool/.system/syslog-cadb1ce96f8c4a01a65be3ef8f5cb996            58.5K  92.3G  58.5K  legacy
boot-pool/.system/webui                                                24K  92.3G    24K  legacy
boot-pool/ROOT                                                       7.41G  92.3G    24K  none
boot-pool/ROOT/13.0-U6.1                                             2.59G  92.3G  1.29G  /
boot-pool/ROOT/24.04.1.1                                             2.28G  92.3G   164M  legacy
boot-pool/ROOT/24.04.1.1/audit                                        229K  92.3G   229K  /audit
boot-pool/ROOT/24.04.1.1/conf                                        42.5K  92.3G  42.5K  /conf
boot-pool/ROOT/24.04.1.1/data                                        98.5K  92.3G  7.57M  /data
boot-pool/ROOT/24.04.1.1/etc                                         3.62M  92.3G  3.10M  /etc
boot-pool/ROOT/24.04.1.1/home                                           0B  92.3G    27K  /home
boot-pool/ROOT/24.04.1.1/mnt                                           25K  92.3G    25K  /mnt
boot-pool/ROOT/24.04.1.1/opt                                         72.0M  92.3G  72.0M  /opt
boot-pool/ROOT/24.04.1.1/root                                        19.5K  92.3G  2.37M  /root
boot-pool/ROOT/24.04.1.1/usr                                         1.88G  92.3G  1.88G  /usr
boot-pool/ROOT/24.04.1.1/var                                         23.0M  92.3G  20.0M  /var
boot-pool/ROOT/24.04.1.1/var/ca-certificates                           24K  92.3G    24K  /var/local/ca-certificates
boot-pool/ROOT/24.04.1.1/var/log                                     2.50M  92.3G  98.6M  /var/log
boot-pool/ROOT/24.04.2                                               2.54G  92.3G   164M  legacy
boot-pool/ROOT/24.04.2/audit                                          509K  92.3G   509K  /audit
boot-pool/ROOT/24.04.2/conf                                          42.5K  92.3G  42.5K  /conf
boot-pool/ROOT/24.04.2/data                                          7.71M  92.3G  7.57M  /data
boot-pool/ROOT/24.04.2/etc                                           3.54M  92.3G  3.07M  /etc
boot-pool/ROOT/24.04.2/home                                            42K  92.3G    27K  /home
boot-pool/ROOT/24.04.2/mnt                                             25K  92.3G    25K  /mnt
boot-pool/ROOT/24.04.2/opt                                           72.0M  92.3G  72.0M  /opt
boot-pool/ROOT/24.04.2/root                                           126M  92.3G   126M  /root
boot-pool/ROOT/24.04.2/usr                                           1.89G  92.3G  1.89G  /usr
boot-pool/ROOT/24.04.2/var                                            298M  92.3G  45.8M  /var
boot-pool/ROOT/24.04.2/var/ca-certificates                             24K  92.3G    24K  /var/local/ca-certificates
boot-pool/ROOT/24.04.2/var/log                                        251M  92.3G   152M  /var/log
boot-pool/ROOT/Initial-Install                                          1K  92.3G  1.29G  legacy
boot-pool/ROOT/default                                                252K  92.3G  1.29G  legacy
boot-pool/grub                                                       6.84M  92.3G  6.84M  legacy
dls-tmp                                                              43.6M  1.76T   168K  /mnt/dls-tmp
dls-tmp/incoming-rtorrent                                             408K  1.76T   408K  /mnt/dls-tmp/incoming-rtorrent
dls-tmp/nzbget-intermediate                                           120K  1.76T   120K  /mnt/dls-tmp/nzbget-intermediate
tank                                                                 6.96T  6.99T   203K  /mnt/tank
tank/.system                                                         2.01G  6.99T  1.25G  legacy
tank/.system/configs-1e9984bcf13340bcb68bc263ecb0a902                 128K  6.99T   128K  legacy
tank/.system/configs-633e2bffa621413eba0de6e902441f76                 363M  6.99T   363M  legacy
tank/.system/cores                                                    186K  1024M   186K  legacy
tank/.system/netdata-633e2bffa621413eba0de6e902441f76                 320M  6.99T   320M  legacy
tank/.system/rrd-1e9984bcf13340bcb68bc263ecb0a902                    10.7M  6.99T  10.7M  legacy
tank/.system/rrd-633e2bffa621413eba0de6e902441f76                    66.0M  6.99T  66.0M  legacy
tank/.system/samba4                                                  8.24M  6.99T   825K  legacy
tank/.system/services                                                 140K  6.99T   140K  legacy
tank/.system/syslog-1e9984bcf13340bcb68bc263ecb0a902                  215K  6.99T   215K  legacy
tank/.system/syslog-633e2bffa621413eba0de6e902441f76                 13.5M  6.99T  13.5M  legacy
tank/.system/webui                                                    128K  6.99T   128K  legacy
tank/VMs                                                             2.55G  6.99T  2.55G  /mnt/tank/VMs
tank/backup-mac-air                                                   215G   385G   215G  /mnt/tank/backup-mac-air
tank/backup-mac-pro-bicou                                             529G   222G   278G  /mnt/tank/backup-mac-pro-bicou
tank/backup-mac-pro-bicou/bicou                                       251G  6.99T   234G  /mnt/tank/backup-mac-pro-bicou/bicou
tank/backup-rtorrent                                                 53.0M  6.99T  53.0M  /mnt/tank/backup-rtorrent
tank/dls                                                             5.11T  6.99T  5.11T  /mnt/tank/dls
tank/dls/rtorrent-session                                            1.11G  6.99T   132M  -
tank/docs                                                             653M  9.36G   652M  /mnt/tank/docs
tank/ftp_home                                                         469M  9.54G   469M  /mnt/tank/ftp_home
tank/home                                                            66.6G   433G  7.20G  /mnt/tank/home
tank/home/bicou                                                      59.4G   433G  59.3G  /mnt/tank/home/bicou
tank/iocage                                                          36.0G  6.99T  24.4M  /mnt/tank/iocage
tank/iocage/download                                                 1.64G  6.99T   151K  /mnt/tank/iocage/download
tank/iocage/download/11.2-RELEASE                                     272M  6.99T   272M  /mnt/tank/iocage/download/11.2-RELEASE
tank/iocage/download/11.3-RELEASE                                     289M  6.99T   289M  /mnt/tank/iocage/download/11.3-RELEASE
tank/iocage/download/12.1-RELEASE                                     371M  6.99T   371M  /mnt/tank/iocage/download/12.1-RELEASE
tank/iocage/download/12.3-RELEASE                                     238M  6.99T   238M  /mnt/tank/iocage/download/12.3-RELEASE
tank/iocage/download/13.1-RELEASE                                     250M  6.99T   250M  /mnt/tank/iocage/download/13.1-RELEASE
tank/iocage/download/13.2-RELEASE                                     256M  6.99T   256M  /mnt/tank/iocage/download/13.2-RELEASE
tank/iocage/download/13.3-RELEASE                                     145K  6.99T   145K  /mnt/tank/iocage/download/13.3-RELEASE
tank/iocage/images                                                    128K  6.99T   128K  /mnt/tank/iocage/images
tank/iocage/jails                                                    26.7G  6.99T   174K  /mnt/tank/iocage/jails
tank/iocage/jails/backup-photos                                       408M  6.99T   163K  /mnt/tank/iocage/jails/backup-photos
tank/iocage/jails/backup-photos/root                                  408M  6.99T  1.18G  /mnt/tank/iocage/jails/backup-photos/root
tank/iocage/jails/flaresolverr                                       1.87G  6.99T   157K  /mnt/tank/iocage/jails/flaresolverr
tank/iocage/jails/flaresolverr/root                                  1.87G  6.99T  2.58G  /mnt/tank/iocage/jails/flaresolverr/root
tank/iocage/jails/hass-metrics                                        511M  6.99T   151K  /mnt/tank/iocage/jails/hass-metrics
tank/iocage/jails/hass-metrics/root                                   511M  6.99T   511M  /mnt/tank/iocage/jails/hass-metrics/root
tank/iocage/jails/kube-rproxy                                        3.81G  6.99T   169K  /mnt/tank/iocage/jails/kube-rproxy
tank/iocage/jails/kube-rproxy/root                                   3.81G  6.99T  3.37G  /mnt/tank/iocage/jails/kube-rproxy/root
tank/iocage/jails/le-validator                                       5.58G  6.99T   169K  /mnt/tank/iocage/jails/le-validator
tank/iocage/jails/le-validator/root                                  5.58G  6.99T  4.24G  /mnt/tank/iocage/jails/le-validator/root
tank/iocage/jails/nzbget                                              892M  6.99T   471K  /mnt/tank/iocage/jails/nzbget
tank/iocage/jails/nzbget/root                                         892M  6.99T   892M  /mnt/tank/iocage/jails/nzbget/root
tank/iocage/jails/plex-plexpass                                      7.56G  6.99T   482K  /mnt/tank/iocage/jails/plex-plexpass
tank/iocage/jails/plex-plexpass/root                                 7.56G  6.99T  7.06G  /mnt/tank/iocage/jails/plex-plexpass/root
tank/iocage/jails/prowlarr                                            289M  6.99T   418K  /mnt/tank/iocage/jails/prowlarr
tank/iocage/jails/prowlarr/root                                       289M  6.99T   289M  /mnt/tank/iocage/jails/prowlarr/root
tank/iocage/jails/sonarr                                              616M  6.99T   407K  /mnt/tank/iocage/jails/sonarr
tank/iocage/jails/sonarr/root                                         616M  6.99T   616M  /mnt/tank/iocage/jails/sonarr/root
tank/iocage/jails/torrent                                            1.34G  6.99T   151K  /mnt/tank/iocage/jails/torrent
tank/iocage/jails/torrent/root                                       1.34G  6.99T  2.01G  /mnt/tank/iocage/jails/torrent/root
tank/iocage/jails/vault                                              3.90G  6.99T   163K  /mnt/tank/iocage/jails/vault
tank/iocage/jails/vault/root                                         3.90G  6.99T  3.42G  /mnt/tank/iocage/jails/vault/root
tank/iocage/log                                                       238K  6.99T   238K  /mnt/tank/iocage/log
tank/iocage/releases                                                 7.65G  6.99T   128K  /mnt/tank/iocage/releases
tank/iocage/releases/11.2-RELEASE                                    2.44G  6.99T   128K  /mnt/tank/iocage/releases/11.2-RELEASE
tank/iocage/releases/11.2-RELEASE/root                               2.44G  6.99T  1.28G  /mnt/tank/iocage/releases/11.2-RELEASE/root
tank/iocage/releases/11.3-RELEASE                                    1.32G  6.99T   128K  /mnt/tank/iocage/releases/11.3-RELEASE
tank/iocage/releases/11.3-RELEASE/root                               1.32G  6.99T  1.32G  /mnt/tank/iocage/releases/11.3-RELEASE/root
tank/iocage/releases/12.1-RELEASE                                    1.71G  6.99T   140K  /mnt/tank/iocage/releases/12.1-RELEASE
tank/iocage/releases/12.1-RELEASE/root                               1.71G  6.99T  1.71G  /mnt/tank/iocage/releases/12.1-RELEASE/root
tank/iocage/releases/12.3-RELEASE                                     811M  6.99T   140K  /mnt/tank/iocage/releases/12.3-RELEASE
tank/iocage/releases/12.3-RELEASE/root                                810M  6.99T   804M  /mnt/tank/iocage/releases/12.3-RELEASE/root
tank/iocage/releases/13.1-RELEASE                                     690M  6.99T   140K  /mnt/tank/iocage/releases/13.1-RELEASE
tank/iocage/releases/13.1-RELEASE/root                                690M  6.99T   690M  /mnt/tank/iocage/releases/13.1-RELEASE/root
tank/iocage/releases/13.2-RELEASE                                     726M  6.99T   140K  /mnt/tank/iocage/releases/13.2-RELEASE
tank/iocage/releases/13.2-RELEASE/root                                726M  6.99T   726M  /mnt/tank/iocage/releases/13.2-RELEASE/root
tank/iocage/templates                                                 128K  6.99T   128K  /mnt/tank/iocage/templates
tank/ix-applications                                                 28.8G  6.99T   186K  /mnt/tank/ix-applications
tank/ix-applications/catalogs                                        58.6M  6.99T  58.6M  /mnt/tank/ix-applications/catalogs
tank/ix-applications/default_volumes                                  140K  6.99T   140K  /mnt/tank/ix-applications/default_volumes
tank/ix-applications/k3s                                             28.8G  6.99T  27.7G  /mnt/tank/ix-applications/k3s
tank/ix-applications/k3s/kubelet                                      874M  6.99T   874M  legacy
tank/ix-applications/releases                                        3.72M  6.99T   174K  /mnt/tank/ix-applications/releases
tank/ix-applications/releases/metallb-config                          796K  6.99T   151K  /mnt/tank/ix-applications/releases/metallb-config
tank/ix-applications/releases/metallb-config/charts                   366K  6.99T   366K  /mnt/tank/ix-applications/releases/metallb-config/charts
tank/ix-applications/releases/metallb-config/volumes                  279K  6.99T   140K  /mnt/tank/ix-applications/releases/metallb-config/volumes
tank/ix-applications/releases/metallb-config/volumes/ix_volumes       140K  6.99T   140K  /mnt/tank/ix-applications/releases/metallb-config/volumes/ix_volumes
tank/ix-applications/releases/rtorrent-rutorrent                      790K  6.99T   151K  /mnt/tank/ix-applications/releases/rtorrent-rutorrent
tank/ix-applications/releases/rtorrent-rutorrent/charts               360K  6.99T   360K  /mnt/tank/ix-applications/releases/rtorrent-rutorrent/charts
tank/ix-applications/releases/rtorrent-rutorrent/volumes              279K  6.99T   140K  /mnt/tank/ix-applications/releases/rtorrent-rutorrent/volumes
tank/ix-applications/releases/rtorrent-rutorrent/volumes/ix_volumes   140K  6.99T   140K  /mnt/tank/ix-applications/releases/rtorrent-rutorrent/volumes/ix_volumes
tank/ix-applications/releases/traefik                                1.16M  6.99T   151K  /mnt/tank/ix-applications/releases/traefik
tank/ix-applications/releases/traefik/charts                          761K  6.99T   761K  /mnt/tank/ix-applications/releases/traefik/charts
tank/ix-applications/releases/traefik/volumes                         279K  6.99T   140K  /mnt/tank/ix-applications/releases/traefik/volumes
tank/ix-applications/releases/traefik/volumes/ix_volumes              140K  6.99T   140K  /mnt/tank/ix-applications/releases/traefik/volumes/ix_volumes
tank/ix-applications/releases/volsync                                 854K  6.99T   140K  /mnt/tank/ix-applications/releases/volsync
tank/ix-applications/releases/volsync/charts                          436K  6.99T   436K  /mnt/tank/ix-applications/releases/volsync/charts
tank/ix-applications/releases/volsync/volumes                         279K  6.99T   140K  /mnt/tank/ix-applications/releases/volsync/volumes
tank/ix-applications/releases/volsync/volumes/ix_volumes              140K  6.99T   140K  /mnt/tank/ix-applications/releases/volsync/volumes/ix_volumes
tank/le-certs                                                        2.90M  6.99T  2.90M  /mnt/tank/le-certs
tank/openebs-zfs                                                      310G  6.99T   140K  /mnt/tank/openebs-zfs
tank/openebs-zfs/pvc-2cf819bf-4f7c-4d17-8511-43bd993d8a1c             140K   100G   140K  legacy
tank/openebs-zfs/pvc-36105ceb-7669-4d2b-892e-b961b96dd085             889K  1023M   889K  legacy
tank/openebs-zfs/pvc-61b3893a-265d-4520-b7e0-c3bc7d20a382             163K   200M   163K  legacy
tank/openebs-zfs/pvc-80ccf375-7947-4787-b4c5-b9894eca3c75             140K   100G   140K  legacy
tank/openebs-zfs/pvc-ab1114da-3a5a-436c-a67d-e08ee3bca21a             140K  99.9M   140K  legacy
tank/openebs-zfs/pvc-cc95554e-0787-4a40-a04a-3e7e5636cdc2             180K   200M   180K  legacy
tank/openebs-zfs/pvc-e6d41379-500e-4eb2-bef7-63dc957f8fd0             140K  99.9M   140K  legacy
tank/openebs-zfs/pvc-fc650377-ca37-4533-80a3-d66e5a6ec89d             310G   190G   310G  legacy
tank/openwrt                                                          866K  6.99T   866K  /mnt/tank/openwrt
tank/photos                                                           615G   613G  26.0G  /mnt/tank/photos
tank/photos/archives-1stcatalog                                       345G   613G   345G  /mnt/tank/photos/archives-1stcatalog
tank/photos/trip-2013                                                 147G   613G   147G  /mnt/tank/photos/trip-2013
tank/photos/trip-2016                                                95.9G   613G  95.9G  /mnt/tank/photos/trip-2016
tank/photos/web                                                      1.48G  98.5G  1.47G  /mnt/tank/photos/web
tank/pxe-nfs                                                         7.27G  6.99T  7.27G  /mnt/tank/pxe-nfs
tank/vault-nas                                                        674K  6.99T   674K  /mnt/tank/vault-nas


---

root@nas:~# cat /etc/exports


"/mnt/tank/le-certs"\
        192.168.12.0/24(sec=sys,no_root_squash,insecure,no_subtree_check)

---

root@nas:~# zpool get all tank
NAME  PROPERTY                       VALUE                          SOURCE
tank  size                           29.1T                          -
tank  capacity                       48%                            -
tank  altroot                        /mnt                           local
tank  health                         ONLINE                         -
tank  guid                           11942675757504622908           -
tank  version                        -                              default
tank  bootfs                         -                              default
tank  delegation                     on                             default
tank  autoreplace                    off                            default
tank  cachefile                      /data/zfs/zpool.cache          local
tank  failmode                       continue                       local
tank  listsnapshots                  off                            default
tank  autoexpand                     off                            default
tank  dedupratio                     1.00x                          -
tank  free                           14.9T                          -
tank  allocated                      14.2T                          -
tank  readonly                       off                            -
tank  ashift                         0                              default
tank  comment                        -                              default
tank  expandsize                     -                              -
tank  freeing                        0                              -
tank  fragmentation                  5%                             -
tank  leaked                         0                              -
tank  multihost                      off                            default
tank  checkpoint                     -                              -
tank  load_guid                      3016248653013050816            -
tank  autotrim                       off                            default
tank  compatibility                  off                            default
tank  bcloneused                     186M                           -
tank  bclonesaved                    186M                           -
tank  bcloneratio                    2.00x                          -
tank  feature@async_destroy          enabled                        local
tank  feature@empty_bpobj            active                         local
tank  feature@lz4_compress           active                         local
tank  feature@multi_vdev_crash_dump  enabled                        local
tank  feature@spacemap_histogram     active                         local
tank  feature@enabled_txg            active                         local
tank  feature@hole_birth             active                         local
tank  feature@extensible_dataset     active                         local
tank  feature@embedded_data          active                         local
tank  feature@bookmarks              enabled                        local
tank  feature@filesystem_limits      enabled                        local
tank  feature@large_blocks           enabled                        local
tank  feature@large_dnode            enabled                        local
tank  feature@sha512                 enabled                        local
tank  feature@skein                  enabled                        local
tank  feature@edonr                  enabled                        local
tank  feature@userobj_accounting     active                         local
tank  feature@encryption             enabled                        local
tank  feature@project_quota          active                         local
tank  feature@device_removal         enabled                        local
tank  feature@obsolete_counts        enabled                        local
tank  feature@zpool_checkpoint       enabled                        local
tank  feature@spacemap_v2            active                         local
tank  feature@allocation_classes     enabled                        local
tank  feature@resilver_defer         enabled                        local
tank  feature@bookmark_v2            enabled                        local
tank  feature@redaction_bookmarks    enabled                        local
tank  feature@redacted_datasets      enabled                        local
tank  feature@bookmark_written       enabled                        local
tank  feature@log_spacemap           active                         local
tank  feature@livelist               enabled                        local
tank  feature@device_rebuild         enabled                        local
tank  feature@zstd_compress          enabled                        local
tank  feature@draid                  enabled                        local
tank  feature@zilsaxattr             active                         local
tank  feature@head_errlog            active                         local
tank  feature@blake3                 enabled                        local
tank  feature@block_cloning          active                         local
tank  feature@vdev_zaps_v2           active                         local

---

root@nas:~# ls -la /dev/disk/by-id/
total 0
drwxr-xr-x 2 root root 1000 Jan 18 21:10 .
drwxr-xr-x 8 root root  160 Jan 18 21:08 ..
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-ST8000VN004-3CP101_WRQ2HCAN -> ../../sdh
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-ST8000VN004-3CP101_WRQ2HCAN-part1 -> ../../sdh1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-ST8000VN004-3CP101_WRQ2HCAN-part2 -> ../../sdh2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5711R -> ../../sde
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5711R-part1 -> ../../sde1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-ST8000VN004-3CP101_WWZ5711R-part2 -> ../../sde2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5QLQ6 -> ../../sdf
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5QLQ6-part1 -> ../../sdf1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-ST8000VN004-3CP101_WWZ5QLQ6-part2 -> ../../sdf2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5VT0V -> ../../sdg
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-ST8000VN004-3CP101_WWZ5VT0V-part1 -> ../../sdg1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-ST8000VN004-3CP101_WWZ5VT0V-part2 -> ../../sdg2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891827 -> ../../sdb
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891827-part1 -> ../../sdb1
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891827-part2 -> ../../sdb2
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891827-part3 -> ../../sdb3
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891828 -> ../../sdc
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891828-part1 -> ../../sdc1
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891828-part2 -> ../../sdc2
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-Verbatim_Vi550_S3_493504108891828-part3 -> ../../sdc3
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2585040 -> ../../sda
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2585040-part1 -> ../../sda1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2585040-part2 -> ../../sda2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2658965 -> ../../sdd
lrwxrwxrwx 1 root root   10 Jan 18 21:08 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2658965-part1 -> ../../sdd1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2658965-part2 -> ../../sdd2
lrwxrwxrwx 1 root root   10 Jan 18 21:10 dm-name-md127 -> ../../dm-0
lrwxrwxrwx 1 root root   10 Jan 18 21:10 dm-uuid-CRYPT-PLAIN-md127 -> ../../dm-0
lrwxrwxrwx 1 root root   11 Jan 18 21:09 md-name-nas:swap0 -> ../../md127
lrwxrwxrwx 1 root root   11 Jan 18 21:09 md-uuid-66735f60:49bf0a44:c11a0e78:14c559f7 -> ../../md127
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x5000c500f73d9c1e -> ../../sdf
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x5000c500f73d9c1e-part1 -> ../../sdf1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x5000c500f73d9c1e-part2 -> ../../sdf2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x5000c500f7440dc6 -> ../../sdg
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x5000c500f7440dc6-part1 -> ../../sdg1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x5000c500f7440dc6-part2 -> ../../sdg2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x5000c500f744c3db -> ../../sdh
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x5000c500f744c3db-part1 -> ../../sdh1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x5000c500f744c3db-part2 -> ../../sdh2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x5000c500f747e131 -> ../../sde
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x5000c500f747e131-part1 -> ../../sde1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x5000c500f747e131-part2 -> ../../sde2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x50014ee25f6cce2a -> ../../sdd
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x50014ee25f6cce2a-part1 -> ../../sdd1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x50014ee25f6cce2a-part2 -> ../../sdd2
lrwxrwxrwx 1 root root    9 Jan 18 21:08 wwn-0x50014ee25f6cd47d -> ../../sda
lrwxrwxrwx 1 root root   10 Jan 18 21:08 wwn-0x50014ee25f6cd47d-part1 -> ../../sda1
lrwxrwxrwx 1 root root   10 Jan 18 21:09 wwn-0x50014ee25f6cd47d-part2 -> ../../sda2


---

root@nas:~# midclt call ftp.config | python3 -m json.tool
{
    "id": 1,
    "port": 21,
    "clients": 10,
    "ipconnections": 10,
    "loginattempt": 5,
    "timeout": 600,
    "timeout_notransfer": 300,
    "rootlogin": false,
    "onlyanonymous": false,
    "anonpath": null,
    "onlylocal": true,
    "banner": "Welcome to nas FTP",
    "filemask": "000",
    "dirmask": "022",
    "fxp": false,
    "resume": true,
    "defaultroot": true,
    "ident": false,
    "reversedns": false,
    "masqaddress": "",
    "passiveportsmin": 5000,
    "passiveportsmax": 5020,
    "localuserbw": 0,
    "localuserdlbw": 0,
    "anonuserbw": 0,
    "anonuserdlbw": 0,
    "tls": true,
    "tls_policy": "off",
    "tls_opt_allow_client_renegotiations": false,
    "tls_opt_allow_dot_login": false,
    "tls_opt_allow_per_user": false,
    "tls_opt_common_name_required": false,
    "tls_opt_enable_diags": false,
    "tls_opt_export_cert_data": false,
    "tls_opt_no_empty_fragments": false,
    "tls_opt_no_session_reuse_required": false,
    "tls_opt_stdenvvars": false,
    "tls_opt_dns_name_required": false,
    "tls_opt_ip_address_required": false,
    "options": "",
    "ssltls_certificate": 1839
}


