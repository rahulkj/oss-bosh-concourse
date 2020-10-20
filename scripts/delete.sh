#!/bin/bash -e

DIR=$(dirname "$(realpath $0)")
BASE_DIR=$(dirname $DIR)

source "$DIR"/load-env.sh
source "$DIR"/releases
source "$DIR"/create-yml

source $BASE_DIR/scripts/bosh-login

DEPLOYMENTS=$(bosh deployments --json | jq -r '.Tables[] | .Rows[] | .name')

if [[ ! -z ${DEPLOYMENTS} ]]; then
  while read -r deployment; do
    bosh delete-deployment -d $deployment -n --force
  done <<< "$DEPLOYMENTS"
fi
bosh clean-up --all -n

createBoshDeploymentVarsFile

bosh delete-env $BASE_DIR/bosh-deployment/bosh.yml \
  --state=$BASE_DIR/$BOSH_ALIAS/state.json \
  --vars-store=$BASE_DIR/$BOSH_ALIAS/bosh-vars.yml \
  -o $BASE_DIR/bosh-deployment/vsphere/cpi.yml \
  -o $BASE_DIR/bosh-deployment/vsphere/resource-pool.yml \
  -o $BASE_DIR/bosh-deployment/misc/dns.yml \
  -o $BASE_DIR/bosh-deployment/jumpbox-user.yml \
  -o $BASE_DIR/bosh-deployment/uaa.yml \
  -o $BASE_DIR/bosh-deployment/credhub.yml \
  -o $BASE_DIR/misc/vsphere-cpi-human-readable.yml \
  -o $BASE_DIR/bosh-deployment/bbr.yml \
  -o $BASE_DIR/misc/bosh-versions.yml \
  -o $BASE_DIR/misc/nsxt.yml \
  -l $BASE_DIR/$BOSH_VAR_FILE \
  -v bbr_release_url="$BBR_RELEASE_URL" \
  -v bbr_release_sha="$BBR_RELEASE_SHA" \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS

rm -rf $BASE_DIR/$BOSH_ALIAS
rm -r $BASE_DIR/$BOSH_VAR_FILE

if [ -f "$BASE_DIR/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-trusty-go_agent.tgz" ]; then
  rm -f $BASE_DIR/bosh-stemcell-*.tgz
fi

unsetDnsOnWifiAdapter
