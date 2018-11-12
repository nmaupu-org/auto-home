#!/bin/sh
## Author: nmaupu

. /etc/rc.subr

name=sickchill
rcvar="${name}_enable"

start_cmd="${name}_start"
stop_cmd="${name}_stop"

sickchill_start() {
  su - sickchill -c "python /home/sickchill/sickchill/SickBeard.py --config /mnt/sickchill-data/sickchill-config.ini --datadir=/mnt/sickchill-data/db > /home/sickchill/logs/sickchill.log 2>/home/sickchill/logs/sickchill-errors.log" &
}

sickchill_stop() {
  pgrep -f SiCKRAGE | xargs kill -9
}

load_rc_config ${name}
run_rc_command "$1"
