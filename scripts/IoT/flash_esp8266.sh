#!/bin/bash

set -e
set -o pipefail

: "${TMP_DIR:=/tmp}"
: "${TASMOTA_VERSION:=v6.7.1}"
: "${TTY:=/dev/tty}"
: "${BAUD_RATE:=115200}"

# Download and install
curl -SsL -o "${TMP_DIR}/sonoff.bin" https://github.com/arendst/Tasmota/releases/download/${TASMOTA_VERSION}/sonoff.bin
esptool.py -p ${TTY} write_flash -fm dio 0x00000 "${TMP_DIR}/sonoff.bin"
