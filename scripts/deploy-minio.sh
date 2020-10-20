#!/bin/bash -e

DIR=$(dirname "$(realpath $0)")
BASE_DIR=$(dirname $DIR)

source "$DIR"/load-env.sh
source "$DIR"/releases
source "$DIR"/bosh-login

MINIO_RELEASE_REPOSITORY=minio/minio-boshrelease
MINIO_RELEASE_VERSION=''

read version sha1 release_url < <(getReleaseDetails $MINIO_RELEASE_REPOSITORY ${MINIO_RELEASE_VERSION:-"NA"})
export MINIO_RELEASE_VERSION=$version
export MINIO_RELEASE_SHA=$sha1
export MINIO_RELEASE_URL=$release_url

uploadRelease "minio" $MINIO_RELEASE_VERSION $MINIO_RELEASE_URL

bosh -n deploy \
  $BASE_DIR/minio.yml -d minio \
  --vars-store=$BASE_DIR/$BOSH_ALIAS/minio-vars.yml \
  -v minio_deployment_name="minio" \
  -v linux_release="$LINUX_RELEASE" \
  -v az_names="$MINIO_AZ_NAMES" \
  -v nw_name="$MINIO_NW_NAME" \
  -v minio_access_port="$MINIO_ACCESS_PORT" \
  -v minio_static_ips="$MINIO_STATIC_IPS" \
  -v minio_vm_type="$MINIO_VM_TYPE" \
  -v minio_disk_type="$MINIO_DISK_TYPE"

##### CONCOURSE DEPLOYMENT END #####
bosh clean-up --all -n
