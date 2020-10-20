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

bosh int $BASE_DIR/$BOSH_ALIAS/bosh-vars.yml --path /director_ssl/ca > $BASE_DIR/$BOSH_ALIAS/director_ssl_ca.pem

bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $BASE_DIR/$BOSH_ALIAS/director_ssl_ca.pem pre-backup-check
bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $BASE_DIR/$BOSH_ALIAS/director_ssl_ca.pem backup --artifact-path $OUTPUT_FOLDER
bbr deployment --target $BOSH_IP --username=$BOSH_CLIENT --deployment concourse --ca-cert $BASE_DIR/$BOSH_ALIAS/director_ssl_ca.pem backup-cleanup

unsetDnsOnWifiAdapter
