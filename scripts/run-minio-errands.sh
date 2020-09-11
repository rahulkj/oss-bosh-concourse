#!/bin/bash -e

__DIR__=$(dirname "$(realpath $0)")

source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/bosh-login

bosh -d minio run-errand bucket-seeding
