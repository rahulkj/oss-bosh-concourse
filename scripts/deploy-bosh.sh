#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASE_DIR__=$(dirname $__DIR__)

## Load all the environment variables and the releases
source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/create-yml

mkdir -p $__BASE_DIR__/$BOSH_ALIAS

createBoshDeploymentVarsFile

## Check to see if the bosh-deployment folder exists, if not then clone it, else pull the latest code
if [ ! -d "$__BASE_DIR__/bosh-deployment" ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment $__BASE_DIR__/bosh-deployment
else
  cd $__BASE_DIR__/bosh-deployment && git pull && cd ..
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
HTTP_PROXY_OPS_FILES=" "
HTTP_PROXY_VARS=" "
if [[ "$BOSH_HTTP_PROXY_REQUIRED" == "true" ]]; then
  HTTP_PROXY_OPS_FILES=" -o $__BASE_DIR__/bosh-deployment/misc/proxy.yml "
  HTTP_PROXY_VARS=" -v http_proxy=$BOSH_HTTP_PROXY \
        -v https_proxy=$BOSH_HTTPS_PROXY \
        -v no_proxy=$BOSH_NO_PROXY "
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
BBR_OPS_FILES=" "
BBR_VARS=" "
if [[ "$BOSH_BACKUPS_REQUIRED" == "true" ]]; then
  BBR_OPS_FILES=" -o $__BASE_DIR__/bosh-deployment/bbr.yml \
    -o $__BASE_DIR__/misc/bbr-versions.yml"
  BBR_VARS="  -v bbr_release_url=\"$BBR_RELEASE_URL\" \
    -v bbr_release_sha=\"$BBR_RELEASE_SHA\" "
fi

VERSIONS_FILE=" "
if [[ "$LATEST_RELEASES" == "true" ]]; then
  VERSIONS_FILE=" -o $__BASE_DIR__/misc/bosh-versions.yml"
fi

NSX_T_OPS_FILE= " "
if [[ ${NSX_T_ENABLED} ]]; then
  NSX_T_OPS_FILE=" -o $__BASE_DIR__/misc/nsxt.yml"
fi

if [[ "${DEBUG}" == "true" ]]; then
  bosh int $__BASE_DIR__/bosh-deployment/bosh.yml \
    --vars-store=$__BASE_DIR__/$BOSH_ALIAS/bosh-vars.yml \
    -o $__BASE_DIR__/bosh-deployment/vsphere/cpi.yml \
    -o $__BASE_DIR__/bosh-deployment/vsphere/resource-pool.yml \
    -o $__BASE_DIR__/bosh-deployment/misc/dns.yml \
    -o $__BASE_DIR__/bosh-deployment/jumpbox-user.yml \
    -o $__BASE_DIR__/bosh-deployment/uaa.yml \
    -o $__BASE_DIR__/bosh-deployment/credhub.yml \
    -o $__BASE_DIR__/misc/bosh-disk.yml \
    -l $__BASE_DIR__/$BOSH_VAR_FILE \
    $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE $NSX_T_OPS_FILE > bosh-int.yml

  exit 1
fi

## Deploy bosh director and enable jumpbox user, backups, uaa and credhub
bosh create-env $__BASE_DIR__/bosh-deployment/bosh.yml \
  --state=$__BASE_DIR__/$BOSH_ALIAS/state.json \
  --vars-store=$__BASE_DIR__/$BOSH_ALIAS/bosh-vars.yml \
  -o $__BASE_DIR__/bosh-deployment/vsphere/cpi.yml \
  -o $__BASE_DIR__/bosh-deployment/vsphere/resource-pool.yml \
  -o $__BASE_DIR__/bosh-deployment/misc/dns.yml \
  -o $__BASE_DIR__/bosh-deployment/jumpbox-user.yml \
  -o $__BASE_DIR__/bosh-deployment/uaa.yml \
  -o $__BASE_DIR__/bosh-deployment/credhub.yml \
  -o $__BASE_DIR__/misc/bosh-disk.yml \
  -l $__BASE_DIR__/$BOSH_VAR_FILE \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $VERSIONS_FILE $NSX_T_OPS_FILE

  # -o $__BASE_DIR__/bosh-deployment/syslog.yml \
  # -o $__BASE_DIR__/misc/syslog.yml \
  # -o $__BASE_DIR__/misc/hm-tsdb.yml \

rm -rf $__BASE_DIR__/$BOSH_VAR_FILE

## Login to bosh director for all the operations that are going to be performed later
source $__BASE_DIR__/scripts/bosh-login

# bosh -n update-runtime-config $__BASE_DIR__/bosh-deployment/runtime-configs/dns.yml

unsetDnsOnWifiAdapter
