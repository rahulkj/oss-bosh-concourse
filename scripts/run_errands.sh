#!/bin/bash -e

FILE_PATH=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(basename -- "$0")")
__DIR__="$( cd "$( dirname "${FILE_PATH}" )" && pwd )"
__BASEDIR__=$(dirname $__DIR__)

source "$__DIR__"/load-env.sh
source "$__DIR__"/releases
source "$__DIR__"/bosh-login

$BOSH_CMD -d minio run-errand bucket-seeding
