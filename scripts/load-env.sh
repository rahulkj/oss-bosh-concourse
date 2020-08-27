#!/bin/bash -e

###
# Description:
#   Loads the environment based on the `FOUNDATION` environment variable;
#     otherwise, loads the env file
#
# Usage:
#   source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/load-env.sh
##

FILE_PATH=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(basename -- "$0")")
__DIR__="$( cd "$( dirname "${FILE_PATH}" )" && pwd )"

export BOSH_CMD=bosh
export VAULT_CMD=vault
export JQ_CMD=jq
export CREDHUB_CMD=credhub

if [[ "$ENV" != "" ]]; then
  echo "sourcing $__DIR__/$ENV-env...."
  source "$__DIR__"/$ENV-env
else
  echo "sourcing $__DIR__/.env...."
  source "$__DIR__"/.env
fi

UNAME=$(uname)
if [[ "$UNAME" == "Darwin" && "$OVERWRITE_MAC_DNS_SERVERS" == "true" ]]; then
  DNS_SERVERS_LIST=( $(echo "$DNS_SERVERS" | $JQ_CMD -r '.[]') )
  networksetup -setdnsservers Wi-Fi $DNS_SERVERS_LIST
fi

export bosh_http_proxy=$BOSH_HTTP_PROXY
export bosh_https_proxy=$BOSH_HTTPS_PROXY

if [[ "$BOSH_HTTP_PROXY_REQUIRED" == "true" ]]; then
  printf -v NO_PROXY '%s,' $(eval echo $BOSH_NO_PROXY_PATTERN)
  export BOSH_NO_PROXY=$BOSH_ADDITIONAL_NO_PROXY_LIST,$NO_PROXY
  export bosh_no_proxy=$BOSH_NO_PROXY
fi

function unsetDnsOnWifiAdapter() {
  UNAME=$(uname)
  if [[ "$UNAME" == "Darwin" && "$OVERWRITE_MAC_DNS_SERVERS" == "true" ]]; then
    networksetup -setdnsservers Wi-Fi Empty
  fi
}

function updateCloudConfig() {
  $BOSH_CMD -n update-cloud-config $__BASEDIR__/cloud-configs/cloud-config.yml \
    -l $__BASEDIR__/cloud-config-vars.yml
}

function uploadRelease() {
  UPLOADED_RELEASES=$($BOSH_CMD releases --json)

  RELEASES_EXISTS=$(echo $UPLOADED_RELEASES | $JQ_CMD --arg release_name $1 \
    --arg release_version $2 \
    '.Tables[] | .Rows[] | select(.name | contains($release_name)) | select(.version | contains($release_version))')

  if [[ -z "$RELEASES_EXISTS" ]]; then
    $BOSH_CMD -n upload-release $3
  else
    echo "Latest release is already deployed, so skipping uploading release: $1 with the version: $2"
  fi
}
