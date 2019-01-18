#!/bin/bash

DIRNAME=`dirname $0`
. ${DIRNAME}/easyopt/easyopt.sh

usage() {
  cat << EOF
Usage: $0 <options>
 -l   list all contexts
 -e   change to the given context
 -h   display this help and exit
EOF
}

list() {
  /usr/local/bin/kubectl config get-contexts -o=name
}

switch() {
  PARAM=$1
  /usr/local/bin/kubectl config use-context "${PARAM}"
}

easyopt_add "l" 'list && exit 0'
easyopt_add "e:" 'switch "$OPTARG" && exit 0'
easyopt_add "h" 'usage && exit 0'
easyopt_parse_opts "$@"

usage && exit 0
