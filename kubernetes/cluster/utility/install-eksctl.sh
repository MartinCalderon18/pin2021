#!/bin/bash
which eksctl > /dev/null && exit 0
. $(dirname $0)/color-prompt.sh
prompt_info "Installing eksctl"
curl -sL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | \
	tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version 2> /dev/null
exit $?