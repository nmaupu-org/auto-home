#!/usr/local/bin/bash

# Force cleaning toprocess directory if somehow files are left here and never deleted
# Thus, avoiding directory to grow for nothing and sickchill to reprocess old files (when force post processing and ticking reprocess)

: ${DIR:=/mnt/toprocess}
: ${DAYS:=15}

find "${DIR}" -type d -depth 1 -mtime +"${DAYS}" | xargs rm -rf
