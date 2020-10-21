#!/bin/bash -e

if [ -z "$__BASE_DIR__" ]; then
  __DIR__=$(dirname "$(realpath $0)")
  __BASE_DIR__=$(dirname $__DIR__)

  source $__DIR__/load-env.sh
fi

export DATE=$(date +"%m-%d-%y")
export OUTPUT_FOLDER=$__BASE_DIR__/concourse-backups/backup-$DATE

if [[ ! -d "$OUTPUT_FOLDER" ]]; then
  mkdir -p $OUTPUT_FOLDER
fi

source "$DIR"/load-env.sh
source $__BASE_DIR__/scripts/bosh-login

bosh int $__BASE_DIR__/$BOSH_ALIAS/bosh-vars.yml --path /jumpbox_ssh/private_key > $__BASE_DIR__/$BOSH_ALIAS/jumpbox.key
bosh int $__BASE_DIR__/$BOSH_ALIAS/bosh-vars.yml --path /director_ssl/ca > $__BASE_DIR__/$BOSH_ALIAS/director_ssl_ca.pem

chmod 600 $__BASE_DIR__/$BOSH_ALIAS/jumpbox.key

bbr director --private-key-path $__BASE_DIR__/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP pre-backup-check
bbr director --private-key-path $__BASE_DIR__/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP backup --artifact-path $OUTPUT_FOLDER
bbr director --private-key-path $__BASE_DIR__/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP backup-cleanup

unsetDnsOnWifiAdapter
