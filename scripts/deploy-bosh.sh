#!/bin/bash -e

DIR=$(dirname "$(realpath $0)")
BASE_DIR=$(dirname $DIR)

## Load all the environment variables and the releases
source "$DIR"/load-env.sh
source "$DIR"/releases
source "$DIR"/create-yml

mkdir -p $BASE_DIR/$BOSH_ALIAS

createBoshDeploymentVarsFile

## Check to see if the bosh-deployment folder exists, if not then clone it, else pull the latest code
if [ ! -d "$BASE_DIR/bosh-deployment" ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment $BASE_DIR/bosh-deployment
else
  cd $BASE_DIR/bosh-deployment && git pull && cd ..
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
HTTP_PROXY_OPS_FILES=" "
HTTP_PROXY_VARS=" "
if [[ "$BOSH_HTTP_PROXY_REQUIRED" == "true" ]]; then
  HTTP_PROXY_OPS_FILES=" -o $BASE_DIR/bosh-deployment/misc/proxy.yml "
  HTTP_PROXY_VARS=" -v http_proxy=$BOSH_HTTP_PROXY \
        -v https_proxy=$BOSH_HTTPS_PROXY \
        -v no_proxy=$BOSH_NO_PROXY "
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
BBR_OPS_FILES=" "
BBR_VARS=" "
if [[ "$BOSH_BACKUPS_REQUIRED" == "true" ]]; then
  BBR_OPS_FILES=" -o $BASE_DIR/bosh-deployment/bbr.yml \
    -o $BASE_DIR/misc/bbr-versions.yml"
  BBR_VARS="  -v bbr_release_url=\"$BBR_RELEASE_URL\" \
    -v bbr_release_sha=\"$BBR_RELEASE_SHA\" "
fi

VERSIONS_FILE=" "
if [[ "$LATEST_RELEASES" == "true" ]]; then
  VERSIONS_FILE=" -o $BASE_DIR/misc/bosh-versions.yml"
fi

if [[ "${DEBUG}" == "true" ]]; then
  bosh int $BASE_DIR/bosh-deployment/bosh.yml \
    --vars-store=$BASE_DIR/$BOSH_ALIAS/bosh-vars.yml \
    -o $BASE_DIR/bosh-deployment/vsphere/cpi.yml \
    -o $BASE_DIR/bosh-deployment/vsphere/resource-pool.yml \
    -o $BASE_DIR/bosh-deployment/misc/dns.yml \
    -o $BASE_DIR/bosh-deployment/jumpbox-user.yml \
    -o $BASE_DIR/bosh-deployment/uaa.yml \
    -o $BASE_DIR/bosh-deployment/credhub.yml \
    -o $BASE_DIR/misc/vsphere-cpi-human-readable.yml \
    -o $BASE_DIR/misc/nsxt.yml \
    -l $BASE_DIR/$BOSH_VAR_FILE \
    $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE > bosh-int.yml

  exit 1
fi

## Deploy bosh director and enable jumpbox user, backups, uaa and credhub
bosh create-env $BASE_DIR/bosh-deployment/bosh.yml \
  --state=$BASE_DIR/$BOSH_ALIAS/state.json \
  --vars-store=$BASE_DIR/$BOSH_ALIAS/bosh-vars.yml \
  -o $BASE_DIR/bosh-deployment/vsphere/cpi.yml \
  -o $BASE_DIR/bosh-deployment/vsphere/resource-pool.yml \
  -o $BASE_DIR/bosh-deployment/misc/dns.yml \
  -o $BASE_DIR/bosh-deployment/jumpbox-user.yml \
  -o $BASE_DIR/bosh-deployment/uaa.yml \
  -o $BASE_DIR/bosh-deployment/credhub.yml \
  -o $BASE_DIR/misc/vsphere-cpi-human-readable.yml \
  -o $BASE_DIR/misc/nsxt.yml \
  -l $BASE_DIR/$BOSH_VAR_FILE \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE

  # -o $BASE_DIR/bosh-deployment/syslog.yml \
  # -o $BASE_DIR/misc/syslog.yml \
  # -o $BASE_DIR/misc/hm-tsdb.yml \

rm -rf $BASE_DIR/$BOSH_VAR_FILE

## Login to bosh director for all the operations that are going to be performed later
source $BASE_DIR/scripts/bosh-login

bosh -n update-runtime-config $BASE_DIR/bosh-deployment/runtime-configs/dns.yml

unsetDnsOnWifiAdapter
