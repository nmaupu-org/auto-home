#!/bin/bash

set -e
set -o pipefail

: "${TMP_DIR:=/tmp}"
: "${TASMOTA_VERSION:=v8.5.1}"
: "${TTY:=/dev/tty}"
: "${BAUD_RATE:=115200}"

# Download and install
curl -SsL -o "${TMP_DIR}/tasmota.bin" https://github.com/arendst/Tasmota/releases/download/${TASMOTA_VERSION}/tasmota.bin
#esptool.py -p ${TTY} erase_flash
esptool.py --port ${TTY} write_flash -fs 1MB -fm dout 0x0 ${TMP_DIR}/tasmota.bin
