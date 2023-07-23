#!/bin/bash

cd $(dirname $0)

. color-prompt.sh

# Check if jq is installed, used to parse kubectl version
./install-jq.sh || exit $?

cleanup() {
	rm kubectl
	exit $1
}

# Check if desired version of kubectl is installed
which kubectl > /dev/null && \
	[[ -z "$KUBECTL_VERSION" || \
		"$(kubectl version --output=json 2> /dev/null | jq -r .clientVersion.gitVersion)" = "$KUBECTL_VERSION" ]] && \
	exit 0

# Install specified kubectl version
[ -z "$KUBECTL_VERSION" ] && KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
prompt_info "Installing kubectl ($KUBECTL_VERSION)"
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" || exit $?
echo $(curl -Ls "https://dl.k8s.io/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256") kubectl | \
	sha256sum -c || cleanup 1
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
cleanup $?