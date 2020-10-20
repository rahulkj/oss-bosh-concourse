#!/bin/bash -e

DIR=$(dirname "$(realpath $0)")

source "$DIR"/load-env.sh
source "$DIR"/releases
source "$DIR"/bosh-login

bosh -d minio run-errand bucket-seeding
