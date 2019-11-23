#!/bin/bash

set -e
set -o pipefail

: "${TTY:=/dev/tty}"
: "${BAUD_RATE:=115200}"
: "${WIFI_SSID_1:=ml-ng}"
: "${WIFI_PASSWORD_1:=yolo}"
: "${WIFI_SSID_2:=ml-ng-bak}"
: "${WIFI_PASSWORD_2:=}"
: "${MQTT_HOST:=mqtt}"
: "${MQTT_USER:=mqtt}"
: "${MQTT_PASSWORD:=mqtt}"
: "${MQTT_TOPIC:=iot}"

# Configuration via serial
stty -f ${TTY} ${BAUD_RATE} | cat << EOF > ${TTY}

Backlog ssid1 ${WIFI_SSID_1}; password1 ${WIFI_PASSWORD_1}; ssid2 ${WIFI_SSID_2}; password2 ${WIFI_PASSWORD_2};
Backlog mqtthost ${MQTT_HOST}; mqttuser ${MQTT_USER}; mqttpassword ${MQTT_PASSWORD}; topic ${MQTT_TOPIC};
Backlog SetOption19 1; setoption53 1; powerretain on; teleperiod 60;
EOF
