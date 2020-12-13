#!/bin/bash

if rsync -ai --delete --copy-links /mnt/certs/letsencrypt/live/hass.home.fossar.net/ /home/homeassistant/certs | grep -q '^>'; then
  chown -R homeassistant: /home/homeassistant/certs && \
    systemctl restart homeassistant
else
  chown -R homeassistant: /home/homeassistant/certs
fi
