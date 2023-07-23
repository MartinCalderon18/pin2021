#!/bin/bash
which jq > /dev/null && exit 0
. $(dirname $0)/color-prompt.sh
prompt_info "Installing jq"
sudo apt update && sudo apt install -y jq
exit $?