#!/bin/bash

set -e
set -o pipefail

# Activing required python virtualenv
# shellcheck source=/dev/null
source /srv/homeassistant/bin/activate
# Load hass-cli configuration env vars
# shellcheck source=/dev/null
source /home/homeassistant/.hass-cli

HASS_DIR=/home/homeassistant/.homeassistant/
BRANCH=origin/master

cd ${HASS_DIR} &>/dev/null

git fetch --all

if ! git diff-index --quiet ${BRANCH} --; then
  git reset --hard ${BRANCH}
  # Reload hass configurations
  hass-cli service call homeassistant.reload_core_config
  hass-cli service call group.reload
  hass-cli service call scene.reload
  hass-cli service call script.reload
  hass-cli service call automation.reload
fi

cd - &>/dev/null
