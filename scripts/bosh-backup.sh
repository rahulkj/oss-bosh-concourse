#!/bin/bash -e

if [ -z "$BASE_DIR" ]; then
  DIR=$(dirname "$(realpath $0)")
  BASE_DIR=$(dirname $DIR)

  source $DIR/load-env.sh
fi

export DATE=$(date +"%m-%d-%y")
export OUTPUT_FOLDER=$BASE_DIR/concourse-backups/backup-$DATE

if [[ ! -d "$OUTPUT_FOLDER" ]]; then
  mkdir -p $OUTPUT_FOLDER
fi

source "$DIR"/load-env.sh
source $BASE_DIR/scripts/bosh-login

bosh int $BASE_DIR/$BOSH_ALIAS/bosh-vars.yml --path /jumpbox_ssh/private_key > $BASE_DIR/$BOSH_ALIAS/jumpbox.key
bosh int $BASE_DIR/$BOSH_ALIAS/bosh-vars.yml --path /director_ssl/ca > $BASE_DIR/$BOSH_ALIAS/director_ssl_ca.pem

chmod 600 $BASE_DIR/$BOSH_ALIAS/jumpbox.key

bbr director --private-key-path $BASE_DIR/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP pre-backup-check
bbr director --private-key-path $BASE_DIR/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP backup --artifact-path $OUTPUT_FOLDER
bbr director --private-key-path $BASE_DIR/$BOSH_ALIAS/jumpbox.key --username jumpbox --host $BOSH_IP backup-cleanup

unsetDnsOnWifiAdapter
