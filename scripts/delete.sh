#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASE_DIR__=$(dirname $__DIR__)

source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/create-yml

source $__BASEDIR__/scripts/bosh-login

DEPLOYMENTS=$(bosh deployments --json | jq -r '.Tables[] | .Rows[] | .name')

if [[ ! -z ${DEPLOYMENTS} ]]; then
  while read -r deployment; do
    bosh delete-deployment -d $deployment -n --force
  done <<< "$DEPLOYMENTS"
fi
bosh clean-up --all -n

createBoshDeploymentVarsFile

bosh delete-env $__BASEDIR__/bosh-deployment/bosh.yml \
  --state=$__BASEDIR__/$BOSH_ALIAS/state.json \
  --vars-store=$__BASEDIR__/$BOSH_ALIAS/bosh-vars.yml \
  -o $__BASEDIR__/bosh-deployment/vsphere/cpi.yml \
  -o $__BASEDIR__/bosh-deployment/vsphere/resource-pool.yml \
  -o $__BASEDIR__/bosh-deployment/misc/dns.yml \
  -o $__BASEDIR__/bosh-deployment/jumpbox-user.yml \
  -o $__BASEDIR__/bosh-deployment/uaa.yml \
  -o $__BASEDIR__/bosh-deployment/credhub.yml \
  -o $__BASEDIR__/misc/vsphere-cpi-human-readable.yml \
  -o $__BASEDIR__/bosh-deployment/bbr.yml \
  -o $__BASEDIR__/misc/bosh-versions.yml \
  -o $__BASEDIR__/misc/nsxt.yml \
  -l $__BASEDIR__/$BOSH_VAR_FILE \
  -v bbr_release_url="$BBR_RELEASE_URL" \
  -v bbr_release_sha="$BBR_RELEASE_SHA" \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS

rm -rf $__BASEDIR__/$BOSH_ALIAS
rm -r $__BASEDIR__/$BOSH_VAR_FILE

if [ -f "$__BASEDIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-trusty-go_agent.tgz" ]; then
  rm -f $__BASEDIR__/bosh-stemcell-*.tgz
fi

unsetDnsOnWifiAdapter
