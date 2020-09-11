#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASEDIR__=$(dirname $__DIR__)

## Load all the environment variables and the releases
source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/create-yml

## Login to bosh director for all the operations that are going to be performed later
source $__BASEDIR__/scripts/bosh-login

## Update the cloud config that the concourse deployment is going to refer to
createCloudConfigVarsFile
updateCloudConfig

# bosh -n update-config --name concourse --type cloud $__BASEDIR__/cloud-configs/vm-extenions-config.yml -v ns_group_name="${CONCOURSE_NS_GROUP_NAME}"

## Check to see if the concourse-bosh-deployment folder exists, if not then clone it, else pull the latest code
if [ ! -d "$__BASEDIR__/concourse-bosh-deployment" ]; then
  git clone https://github.com/concourse/concourse-bosh-deployment $__BASEDIR__/concourse-bosh-deployment
else
  git checkout master
fi

## Switch to the right concourse-bosh-deployment version branch for the given $CONCOURSE_RELEASE_VERSION
set +e
pushd $__BASEDIR__/concourse-bosh-deployment
  git fetch --all
  git checkout v$CONCOURSE_RELEASE_VERSION
  git pull
popd
set -e

## Download the latest stemcell from bosh.io and remove the old ones from the local file system
if [[ ! -f "$__BASEDIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz" ]]; then
  rm -f $__BASEDIR__/bosh-stemcell-*.tgz
  wget -O $__BASEDIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz \
        https://s3.amazonaws.com/bosh-core-stemcells/$SC_VERSION/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz
fi

## Upload the stemcell to bosh director
bosh -n upload-stemcell $__BASEDIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz

## If $LATEST_RELEASES is true, then deploy all the latest releases for concourse, garden-runc, postgres, backup-and-restore-sdk. Else use the releases defined in the concourse-bosh-deployment/versions.yml
if [[ "$LATEST_RELEASES" == "false" ]]; then
  CONCOURSE_VERSIONS_TO_DEPLOY="-l $__BASEDIR__/concourse-bosh-deployment/versions.yml"
else
  CONCOURSE_VERSIONS_TO_DEPLOY="-o $__BASEDIR__/ops-files/concourse-versions.yml \
    -v concourse_release_version=\"$CONCOURSE_RELEASE_VERSION\" \
    -v garden_runc_release_version=\"$GARDEN_RUNC_RELEASE_VERSION\" \
    -v postgres_release_version=\"$POSTGRES_RELEASE_VERSION\" \
    -v bpm_release_version=\"$BPM_RELEASE_VERSION\""

  uploadRelease "concourse" $CONCOURSE_RELEASE_VERSION $CONCOURSE_RELEASE_URL
  uploadRelease "garden-runc" $GARDEN_RUNC_RELEASE_VERSION $GARDEN_RUNC_RELEASE_URL
  uploadRelease "postgres" $POSTGRES_RELEASE_VERSION $POSTGRES_RELEASE_URL
  uploadRelease "bpm" $BPM_RELEASE_VERSION $BPM_RELEASE_URL
  uploadRelease "uaa" $UAA_RELEASE_VERSION $UAA_RELEASE_URL
  uploadRelease "credhub" $CREDHUB_RELEASE_VERSION $CREDHUB_RELEASE_URL
fi

## If HTTP Proxy is needed include the proxy ops files while deploying concourse
HTTP_PROXY_OPS_FILES=" "
HTTP_PROXY_VARS=" "
if [[ "$BOSH_HTTP_PROXY_REQUIRED" == "true" ]]; then
  HTTP_PROXY_OPS_FILES=" -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/http-proxy.yml "
  HTTP_PROXY_VARS=" -v proxy_url=$BOSH_HTTP_PROXY \
    -v no_proxy=[$BOSH_NO_PROXY] "
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
BBR_OPS_FILES=" "
BBR_VARS=" "
if [[ "$CONCOURSE_BACKUPS_REQUIRED" == "true" ]]; then
  uploadRelease "backup-and-restore-sdk" $BBR_RELEASE_VERSION $BBR_RELEASE_URL
  BBR_OPS_FILES=" -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/backup-atc.yml \
    -o $__BASEDIR__/credhub/backup-credhub.yml"
fi

createConcourseDeploymentVarsFile

#### CONCOURSE DEPLOYMENT START #####
bosh -n deploy $__BASEDIR__/concourse-bosh-deployment/cluster/concourse.yml \
  -d concourse \
  $CONCOURSE_VERSIONS_TO_DEPLOY \
  -o $__BASEDIR__/ops-files/nws-azs.yml \
  -o $__BASEDIR__/ops-files/stemcell.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/scale.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/basic-auth.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/github-auth.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/credhub-path-prefix.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/privileged-http.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/privileged-https.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/worker-max-in-flight.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/worker-rebalancing.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/worker-volume-sweeper-max-in-flight.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/tls.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/tls-vars.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/uaa.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/credhub-colocated.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-credhub.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-uaa.yml \
  -o $__BASEDIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-bbr.yml \
  -l $__BASEDIR__/$CONCOURSE_VAR_FILE \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS
  # -o $__BASEDIR__/ops-files/vm-extensions.yml \

##### CONCOURSE DEPLOYMENT END #####

## cleanup bosh director and remove the unused releases and stemcells
bosh clean-up --all -n

rm -rf $__BASEDIR__/$CLOUD_CONFIG_VAR_FILE
rm -rf $__BASEDIR__/$CONCOURSE_VAR_FILE

unsetDnsOnWifiAdapter
