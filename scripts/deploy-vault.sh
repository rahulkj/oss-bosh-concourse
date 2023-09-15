#!/bin/bash

uploadRelease "consul" $CONSUL_RELEASE_VERSION $CONSUL_RELEASE_URL $CONSUL_RELEASE_SHA
uploadRelease "vault" $VAULT_RELEASE_VERSION $VAULT_RELEASE_URL $VAULT_RELEASE_SHA

##### VAULT DEPLOYMENT START #####
VAULT_TLS_FLAGS="--vars-store $__BASE_DIR__/$BOSH_ALIAS/vault-vars.yml"
if [[ ! -z "$VAULT_SERVER_CERT_FILENAME" ]]; then
  VAULT_TLS_FLAGS="--var-file vault-tls.certificate=$VAULT_SERVER_CERT_FILENAME --var-file vault-tls.private_key=$VAULT_PRIVATE_KEY_FILENAME"
  echo "Using provided Vault cert"
else
  echo "Generating cert for Vault"
fi

bosh -n -d vault deploy $__BASE_DIR__/vault/vault.yml \
  -v VAULT_AZ_NAME="$VAULT_AZ_NAME" \
  -v VAULT_NW_NAME="$VAULT_NW_NAME" \
  -v STATIC_IPS="$VAULT_STATIC_IPS" \
  -v VAULT_INSTANCES="$VAULT_INSTANCES" \
  -v VAULT_VM_TYPE="$VAULT_VM_TYPE" \
  -v VAULT_DISK_TYPE="$VAULT_DISK_TYPE" \
  -v LOAD_BALANCER_URL="$VAULT_LOAD_BALANCER_URL" \
  -v VAULT_TCP_PORT="$VAULT_TCP_PORT" \
  $VAULT_TLS_FLAGS
##### VAULT DEPLOYMENT END #####

##### VAULT CONFIGURATION START #####
# Initialize vault

set +e
IS_VAULT_INTIALIZED=$(curl -m 10 -s -o /dev/null -w "%{http_code}" $VAULT_ADDR/v1/sys/health)
set -e

if [ $IS_VAULT_INTIALIZED -eq 501 ]; then
  echo "Initalizing Vault"

  VAULT_INIT_RESPONSE=$(vault init)

  rm -rf $__BASE_DIR__/$BOSH_ALIAS/vault.log

  echo "$VAULT_INIT_RESPONSE" > $__BASE_DIR__/$BOSH_ALIAS/vault.log

  # Unseal the vault
  IPS=`bosh vms -d vault --json | jq -r '.Tables[0].Rows[] | .ips'`
  for ip in $IPS; do
    $__BASE_DIR__/scripts/vault-unseal.sh http://$ip
  done

elif [ $IS_VAULT_INTIALIZED -eq 503 ]; then
  # Unseal the vault
  echo "Unsealing vault"
  IPS=`bosh vms -d vault --json | jq -r '.Tables[0].Rows[] | .ips'`
  for ip in $IPS; do
    $__BASE_DIR__/scripts/vault-unseal.sh http://$ip
  done
elif [ $IS_VAULT_INTIALIZED -eq 500 ]; then
  echo "Vault is hosed.. troubleshoot it using bosh commands"
  exit 1
elif [ $IS_VAULT_INTIALIZED -eq 000 ]; then
  echo "Unable to connect to $VAULT_ADDR.. Could be DNS, or certificates error"
  exit 1
else
  echo "Vault already initialized and hence skipping this step"
fi

### Token based authentication ###
# Create a token with the specified policy

## Approle based authentication ###
# vault auth-enable approle
# vault write auth/approle/role/$ROLE_NAME policies=$VAULT_POLICY_NAME -period="87600h"
# export ROLE_ID=$(vault read -format=json auth/approle/role/$ROLE_NAME/role-id | jq .data.role_id | tr -d '"')
# export SECRET_ID=$(vault write -format=json -f auth/approle/role/$ROLE_NAME/secret-id | jq .data.secret_id | tr -d '"')
# export CLIENT_TOKEN=$(vault write -format=json auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID | jq .auth.client_token | tr -d '"')

#### VAULT CONFIGURATION END #####

if [[ ! -e $__BASE_DIR__/$BOSH_ALIAS/create_token_response.json ]]; then
  export VAULT_TOKEN=$(cat $__BASE_DIR__/$BOSH_ALIAS/vault.log | grep 'Initial Root Token' | awk '{print $4}')
  # Create a mount for concourse
  vault secrets enable -path=$CONCOURSE_VAULT_MOUNT -description="Secrets for use by concourse pipelines" generic

  # Create application policy
  vault policy write $VAULT_POLICY_NAME $__BASE_DIR__/vault/vault-policy.hcl
  CREATE_TOKEN_RESPONSE=$(vault token create --policy=$VAULT_POLICY_NAME -period="87600h" -format=json)
  rm -rf $__BASE_DIR__/$BOSH_ALIAS/create_token_response.json
  echo $CREATE_TOKEN_RESPONSE > $__BASE_DIR__/$BOSH_ALIAS/create_token_response.json
fi
