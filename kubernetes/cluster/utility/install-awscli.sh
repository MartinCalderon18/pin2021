#!/bin/bash

# Check if awscli is already installed
which aws > /dev/null && exit 0

. $(dirname $0)/color-prompt.sh

cleanup() {
	rm -fr awscliv2.zip aws
	exit $1
}

# Check if unzip is installed
if ! which unzip > /dev/null; then
	sudo apt update && \
	sudo apt install -y unzip || \
	exit 1
fi

prompt_info "Installing awscli (v2)"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
cd /tmp
unzip awscliv2.zip
if ! sudo ./aws/install; then
	prompt_error "Failed to install aws cli"
	cleanup 1
fi

# Configure awscli
prompt_info "Please enter AWS credentials"
aws configure

cleanup $?