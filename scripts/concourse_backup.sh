#!/bin/bash -e

if [ -z "$__BASEDIR__" ]; then
  FILE_PATH=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(basename -- "$0")")
  __DIR__="$( cd "$( dirname "${FILE_PATH}" )" && pwd )"
  __BASEDIR__=$(dirname $__DIR__)

  source $__DIR__/load-env.sh
fi

export DATE=$(date +"%m-%d-%y")
export OUTPUT_FOLDER=$__BASEDIR__/concourse-backups/backup-$DATE

if [[ ! -d "$OUTPUT_FOLDER" ]]; then
  mkdir -p $OUTPUT_FOLDER
fi

source "$__DIR__"/load-env.sh
source $__BASEDIR__/scripts/bosh-login

$BOSH_CMD int $__BASEDIR__/$BOSH_ALIAS/bosh-vars.yml --path /director_ssl/ca > $__BASEDIR__/$BOSH_ALIAS/director_ssl_ca.pem

bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $__BASEDIR__/$BOSH_ALIAS/director_ssl_ca.pem pre-backup-check
bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $__BASEDIR__/$BOSH_ALIAS/director_ssl_ca.pem backup --artifact-path $OUTPUT_FOLDER
bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $__BASEDIR__/$BOSH_ALIAS/director_ssl_ca.pem backup-cleanup

unsetDnsOnWifiAdapter
