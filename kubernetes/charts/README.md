# Upgrading deluge

```
helm upgrade avlm avlm --set \
couchpotato.downloader.username=$(vault read -field=daemon_username secret/deluge),\
couchpotato.downloader.password=$(vault read -field=daemon_password secret/deluge),\
couchpotato.downloader.host=$(vault read -field=daemon_server secret/deluge),\
couchpotato.downloader.port=$(vault read -field=daemon_port secret/deluge),\
couchpotato.torrent_source.username=$(vault read -field=username secret/torrentleech.org),\
couchpotato.torrent_source.password=$(vault read -field=password secret/torrentleech.org)
```
