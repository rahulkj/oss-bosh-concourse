#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASEDIR__=$(dirname $__DIR__)

source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/bosh-login

MINIO_RELEASE_REPOSITORY=minio/minio-boshrelease
MINIO_RELEASE_VERSION=''

read version sha1 release_url < <(getReleaseDetails $MINIO_RELEASE_REPOSITORY ${MINIO_RELEASE_VERSION:-"NA"})
export MINIO_RELEASE_VERSION=$version
export MINIO_RELEASE_SHA=$sha1
export MINIO_RELEASE_URL=$release_url

uploadRelease "minio" $MINIO_RELEASE_VERSION $MINIO_RELEASE_URL

bosh -n deploy \
  $__BASEDIR__/minio.yml -d minio \
  --vars-store=$__BASEDIR__/$BOSH_ALIAS/minio-vars.yml \
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
