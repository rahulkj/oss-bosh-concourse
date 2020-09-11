#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")
__BASE_DIR__=$(dirname $__DIR__)

source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/bosh-login

bosh upload-release --sha1 6da3a6f4f33ada63ecef9ae39c2739f3af60d760 \
  https://bosh.io/d/github.com/cloudfoundry-community/logsearch-boshrelease?v=210.0.0

bosh upload-release --sha1 c69ad70cf778cb70a92e51606be9be94d656521e \
  https://bosh.io/d/github.com/cloudfoundry-community/logsearch-for-cloudfoundry?v=210.0.0

git clone https://github.com/cloudfoundry-community/logsearch-boshrelease $__BASEDIR__/logsearch-boshrelease

pushd $__BASEDIR__/logsearch-boshrelease/deployment

# rm -rf logsearch.yml

bosh int logsearch-deployment.yml \
  -o operations/scale-to-one-az.yml \
  -o operations/change-azs.yml \
  -o operations/rename-network.yml \
  -o operations/change-disk-types.yml \
  -o operations/change-vm-types.yml \
  -o operations/cloudfoundry.yml \
  -v azs='["default"]' \
  -v elasticsearch_master_disk_type="5120" \
  -v cluster_monitor_disk_type="51200" \
  -v elasticsearch_data_disk_type="51200" \
  -v ingestor_disk_type="5120" \
  -v kibana_disk_type="5120" \
  -v ingestor_disk_type="5120" \
  -v elasticsearch_master_vm_type="medium" \
  -v cluster_monitor_vm_type="large" \
  -v maintenance_vm_type="medium" \
  -v elasticsearch_data_vm_type="large" \
  -v ingestor_vm_type="large" \
  -v kibana_vm_type="large" \
  -v ls_router_vm_type="medium" \
  -v redis_disk_type="2048" \
  -v redis_vm_type="medium.mem" \
  -v network_name="default" \
  -v uaa_admin_client_secret="ATEa-PMQ4uZ52TnOlQMQhbY9NE3JzSFi" \
  -v cf_admin_password="EKdwIuTl27OnqGcFIICQzRF_S9ljXByY" \
  -v system_domain="sys.homelab.io"
  -o overrides.yml  > logsearch.yml

bosh -d logsearch deploy -n logsearch-deployment.yml \
  -o operations/scale-to-one-az.yml \
  -o operations/change-azs.yml \
  -o operations/rename-network.yml \
  -o operations/change-disk-types.yml \
  -o operations/change-vm-types.yml \
  -o operations/cloudfoundry.yml \
  -o operations/change-cf-deployment-name.yml \
  -o operations/push-cloudfoundry-kibana.yml \
  -v azs='["AZ-2"]' \
  -v elasticsearch_master_disk_type="5120" \
  -v cluster_monitor_disk_type="51200" \
  -v elasticsearch_data_disk_type="51200" \
  -v ingestor_disk_type="5120" \
  -v kibana_disk_type="5120" \
  -v ingestor_disk_type="5120" \
  -v elasticsearch_master_vm_type="medium" \
  -v cluster_monitor_vm_type="large" \
  -v maintenance_vm_type="medium" \
  -v elasticsearch_data_vm_type="large" \
  -v ingestor_vm_type="large" \
  -v kibana_vm_type="large" \
  -v ls_router_vm_type="medium" \
  -v redis_disk_type="2048" \
  -v redis_vm_type="medium.mem" \
  -v network_name="SERVICES" \
  -v uaa_admin_client_secret="EKdwIuTl27OnqGcFIICQzRF_S9ljXByY" \
  -v cf_admin_password="ATEa-PMQ4uZ52TnOlQMQhbY9NE3JzSFi" \
  -v system_domain="sys.homelab.io" \
  -v cf_deployment_name=cf-5c3e2793d390f4ef95f8 \
  -v api_security_group=default_security_group \
  -o override.yml \
  -v system_org=system

popd
