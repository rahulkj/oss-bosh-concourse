#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASE_DIR__=$(dirname $__DIR__)

## Load all the environment variables and the releases
source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/create-yml

mkdir -p $__BASEDIR__/$BOSH_ALIAS

createBoshDeploymentVarsFile

## Check to see if the bosh-deployment folder exists, if not then clone it, else pull the latest code
if [ ! -d "$__BASEDIR__/bosh-deployment" ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment $__BASEDIR__/bosh-deployment
else
  cd $__BASEDIR__/bosh-deployment && git pull && cd ..
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
HTTP_PROXY_OPS_FILES=" "
HTTP_PROXY_VARS=" "
if [[ "$BOSH_HTTP_PROXY_REQUIRED" == "true" ]]; then
  HTTP_PROXY_OPS_FILES=" -o $__BASEDIR__/bosh-deployment/misc/proxy.yml "
  HTTP_PROXY_VARS=" -v http_proxy=$BOSH_HTTP_PROXY \
        -v https_proxy=$BOSH_HTTPS_PROXY \
        -v no_proxy=$BOSH_NO_PROXY "
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
BBR_OPS_FILES=" "
BBR_VARS=" "
if [[ "$BOSH_BACKUPS_REQUIRED" == "true" ]]; then
  BBR_OPS_FILES=" -o $__BASEDIR__/bosh-deployment/bbr.yml \
    -o $__BASEDIR__/misc/bbr-versions.yml"
  BBR_VARS="  -v bbr_release_url=\"$BBR_RELEASE_URL\" \
    -v bbr_release_sha=\"$BBR_RELEASE_SHA\" "
fi

VERSIONS_FILE=" "
if [[ "$LATEST_RELEASES" == "true" ]]; then
  VERSIONS_FILE=" -o $__BASEDIR__/misc/bosh-versions.yml"
fi

if [[ "${DEBUG}" == "true" ]]; then
  bosh int $__BASEDIR__/bosh-deployment/bosh.yml \
    --vars-store=$__BASEDIR__/$BOSH_ALIAS/bosh-vars.yml \
    -o $__BASEDIR__/bosh-deployment/vsphere/cpi.yml \
    -o $__BASEDIR__/bosh-deployment/vsphere/resource-pool.yml \
    -o $__BASEDIR__/bosh-deployment/misc/dns.yml \
    -o $__BASEDIR__/bosh-deployment/jumpbox-user.yml \
    -o $__BASEDIR__/bosh-deployment/uaa.yml \
    -o $__BASEDIR__/bosh-deployment/credhub.yml \
    -o $__BASEDIR__/misc/vsphere-cpi-human-readable.yml \
    -o $__BASEDIR__/misc/nsxt.yml \
    -l $__BASEDIR__/$BOSH_VAR_FILE \
    $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE > bosh-int.yml

  exit 1
fi

## Deploy bosh director and enable jumpbox user, backups, uaa and credhub
bosh create-env $__BASEDIR__/bosh-deployment/bosh.yml \
  --state=$__BASEDIR__/$BOSH_ALIAS/state.json \
  --vars-store=$__BASEDIR__/$BOSH_ALIAS/bosh-vars.yml \
  -o $__BASEDIR__/bosh-deployment/vsphere/cpi.yml \
  -o $__BASEDIR__/bosh-deployment/vsphere/resource-pool.yml \
  -o $__BASEDIR__/bosh-deployment/misc/dns.yml \
  -o $__BASEDIR__/bosh-deployment/jumpbox-user.yml \
  -o $__BASEDIR__/bosh-deployment/uaa.yml \
  -o $__BASEDIR__/bosh-deployment/credhub.yml \
  -o $__BASEDIR__/misc/vsphere-cpi-human-readable.yml \
  -o $__BASEDIR__/misc/nsxt.yml \
  -l $__BASEDIR__/$BOSH_VAR_FILE \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE

  # -o $__BASEDIR__/bosh-deployment/syslog.yml \
  # -o $__BASEDIR__/misc/syslog.yml \
  # -o $__BASEDIR__/misc/hm-tsdb.yml \

rm -rf $__BASEDIR__/$BOSH_VAR_FILE

## Login to bosh director for all the operations that are going to be performed later
source $__BASEDIR__/scripts/bosh-login

bosh -n update-runtime-config $__BASEDIR__/bosh-deployment/runtime-configs/dns.yml

unsetDnsOnWifiAdapter
