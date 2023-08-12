#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASE_DIR__=$(dirname $__DIR__)

## Load all the environment variables and the releases
source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/create-yml

## Login to bosh director for all the operations that are going to be performed later
source $__BASE_DIR__/scripts/bosh-login

## Update the cloud config that the concourse deployment is going to refer to
createCloudConfigVarsFile
updateCloudConfig

## Check to see if the concourse-bosh-deployment folder exists, if not then clone it, else pull the latest code
if [ ! -d "$__BASE_DIR__/concourse-bosh-deployment" ]; then
  git clone https://github.com/concourse/concourse-bosh-deployment $__BASE_DIR__/concourse-bosh-deployment
else
  git checkout master
fi

## Switch to the right concourse-bosh-deployment version branch for the given $CONCOURSE_RELEASE_VERSION
set +e
pushd $__BASE_DIR__/concourse-bosh-deployment
  git fetch --all
  git checkout v$CONCOURSE_RELEASE_VERSION
  git pull
popd
set -e

## Download the latest stemcell from bosh.io and remove the old ones from the local file system
if [[ ! -f "$__BASE_DIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz" ]]; then
  rm -f $__BASE_DIR__/bosh-stemcell-*.tgz
  wget -O $__BASE_DIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz \
    https://storage.googleapis.com/bosh-core-stemcells/$SC_VERSION/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz
fi

## Upload the stemcell to bosh director
bosh -n upload-stemcell $__BASE_DIR__/bosh-stemcell-$SC_VERSION-vsphere-esxi-ubuntu-$LINUX_RELEASE-go_agent.tgz

## If $LATEST_RELEASES is true, then deploy all the latest releases for concourse, garden-runc, postgres, backup-and-restore-sdk. Else use the releases defined in the concourse-bosh-deployment/versions.yml
if [[ "$LATEST_RELEASES" == "false" ]]; then
  CONCOURSE_VERSIONS_TO_DEPLOY="-l $__BASE_DIR__/concourse-bosh-deployment/versions.yml"
else
  CONCOURSE_VERSIONS_TO_DEPLOY="-o $__BASE_DIR__/ops-files/concourse-versions.yml \
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
  HTTP_PROXY_OPS_FILES=" -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/http-proxy.yml "
  HTTP_PROXY_VARS=" -v proxy_url=$BOSH_HTTP_PROXY \
    -v no_proxy=[$BOSH_NO_PROXY] "
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
BBR_OPS_FILES=" "
BBR_VARS=" "
if [[ "$CONCOURSE_BACKUPS_REQUIRED" == "true" ]]; then
  uploadRelease "backup-and-restore-sdk" $BBR_RELEASE_VERSION $BBR_RELEASE_URL
  BBR_OPS_FILES=" -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/backup-atc.yml \
    -o $__BASE_DIR__/credhub/backup-credhub.yml \
    -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-bbr.yml"
fi

## If HTTP Proxy is needed include the proxy ops files while deploying bosh
SKIP_MTLS_OPS_FILES=" "
if [[ "$CONCOURSE_MTLS_REQUIRED" == "false" ]]; then
  SKIP_MTLS_OPS_FILES=" -o $__BASE_DIR__/ops-files/web-skip-mtls.yml"
fi

createConcourseDeploymentVarsFile

DEPLOY_OPTION="-n deploy"
if [[ "$INTERPOLATE" == "true" ]]; then
  DEPLOY_OPTION="int"
fi

#### CONCOURSE DEPLOYMENT START #####
bosh $DEPLOY_OPTION $__BASE_DIR__/concourse-bosh-deployment/cluster/concourse.yml \
  -d concourse \
  $CONCOURSE_VERSIONS_TO_DEPLOY \
  -o $__BASE_DIR__/ops-files/nws-azs.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/basic-auth.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/github-auth.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/credhub-path-prefix.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/privileged-http.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/privileged-https.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/tls.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/tls-vars.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/uaa.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/credhub-colocated.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/scale.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-credhub.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-uaa.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/worker-max-in-flight.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/worker-rebalancing.yml \
  -o $__BASE_DIR__/concourse-bosh-deployment/cluster/operations/worker-volume-sweeper-max-in-flight.yml \
  -l $__BASE_DIR__/$CONCOURSE_VAR_FILE \
  $HTTP_PROXY_OPS_FILES $HTTP_PROXY_VARS $BBR_OPS_FILES $BBR_VARS $SKIP_MTLS_OPS_FILES

##### CONCOURSE DEPLOYMENT END #####

## cleanup bosh director and remove the unused releases and stemcells
bosh clean-up --all -n

rm -rf $__BASE_DIR__/$CLOUD_CONFIG_VAR_FILE
rm -rf $__BASE_DIR__/$CONCOURSE_VAR_FILE

unsetDnsOnWifiAdapter
