#!/bin/bash

set -o pipefail

# AWS user profile name
PROFILE=default

# EKS configuration variables
NAME=tcss702-eks
REGION=us-east-1
ZONES=us-east-1b,us-east-1c
NODE_SIZE=t3.medium
NODE_COUNT=5
SSH_PUBLIC_KEY=temporal
#NETWORK_CNI=calico
K8S_VERSION=1.23
# Kubernetes and kubectl version must be within one minor version of each other
export KUBECONFIG=$HOME/.kube/eksctl/clusters/$NAME
export KUBECTL_VERSION='v1.25.4'

LOG_DIR='../logs/eks'

cd $(dirname $0)

# Add colorized console prompt
. ./utility/color-prompt.sh || exit 1


# Display script usage/flags for user
usage() {
	cat <<- _USAGE
	Usage: $(basename $0) [Options]

	Description: This script will instantiate an EKS kubernetes cluster on AWS

	Options:
	  -d|--delete, deletes a running cluster and all underlying infrastructure
	  -e|--edit, edit cluster configuration before deployment
	  -f|--filename <cluster-spec.yml>, pass a custom cluster spec
	  -h|--help, print this message
	  -s|--suffix, appended folder on log directory (e.g. logs/eks/<suffix>)
	_USAGE
}


# Check for and install dependencies
# install_dependencies() {
# 	./utility/install-kubectl.sh || return $?
# 	./utility/install-eksctl.sh || return $?
# 	./utility/install-jq.sh || return $?
# 	./utility/install-awscli.sh
# 	return $?
# }


# An IAM user must be created in AWS with permissions to create a cluster
create_eks_iam_user() {
	grep -q $PROFILE $HOME/.aws/credentials && return 0

	# minimum IAM policies per,
	# https://eksctl.io/usage/minimum-iam-policies
	local managed_policies=(\
		AmazonEC2FullAccess \
		AWSCloudFormationFullAccess \
	)
	# self-managed IAM policies
	local policies=(\
		EksAllAccess \
		IamLimitedAccess \
	)
	# get AWS account ID
	local aws_id=$(aws sts get-caller-identity | jq -r .Account)

	if ! aws iam get-user --user $PROFILE &> /dev/null; then
		aws iam create-group --group-name $PROFILE || return $?

		# Attach managed policies to group
		for p in ${managed_policies[@]}; do
			aws iam attach-group-policy \
				--policy-arn arn:aws:iam::aws:policy/$p \
				--group-name $PROFILE || return $?
		done

		# Attach self-managed policies to group
		for p in ${policies[@]}; do
			# Check if policy has already been created
			if ! aws iam get-policy --policy-arn arn:aws:iam::$aws_id:policy/$p 2> /dev/null; then
				# policy json
				local json=$(sed "s/<account_id>/$aws_id/" eks/$p.json)
				aws iam create-policy \
					--policy-name $p \
					--policy-document "$json"
			fi
			aws iam attach-group-policy \
				--policy-arn arn:aws:iam::$aws_id:policy/$p \
				--group-name $PROFILE || return $?
		done

		aws iam create-user --user-name $PROFILE || return $?
		aws iam add-user-to-group --user-name $PROFILE --group-name $PROFILE || \
			return $?
	fi

	# Create Access Key ID and Secret Access Key
	local tmp=$(mktemp)
	if ! aws iam create-access-key --user-name $PROFILE > $tmp; then
		local ret=$?
		rm $tmp
		return $ret
	fi
	local access_key=$(jq -r .AccessKey.AccessKeyId < $tmp)
	local secret_key=$(jq -r .AccessKey.SecretAccessKey < $tmp)

	# Populate AWS credentials
	cat <<- _CREDENTIALS >> $HOME/.aws/credentials

	[$PROFILE]
	aws_access_key_id=$access_key
	aws_secret_access_key=$secret_key
	_CREDENTIALS

	# Populate AWS config
	cat <<- _CONFIG >> $HOME/.aws/config

	[profile $PROFILE]
	region=$REGION
	_CONFIG

	# Remove temporary AWS config file
	rm $tmp

	# Give some time for credentials to be activated
	# for some reason this does not seem to happen quickly
	sleep 10

	return 0
}


# Create an EKS cluster
create_custer() {
	# Create log for EKS deployment
	if [ -z "$CLUSTER_SPEC" ]; then
		LOG+=_eks_deployment.log
	else
		LOG+=_${NAME}_deployment.log
	fi

	# Make kube config directory
	mkdir -p $(dirname $KUBECONFIG)

	local start=$(date +%s)
	# Create cluster configuration
	if [ -z "$CLUSTER_SPEC" ]; then
		eksctl create cluster \
			--name $NAME \
			--region $REGION \
			--zones $ZONES \
			--with-oidc \
			--instance-types $NODE_SIZE \
			--nodes $NODE_COUNT \
			--version $K8S_VERSION \
			--ssh-access=true \
			--ssh-public-key=$SSH_PUBLIC_KEY \
			--auto-kubeconfig \
			--spot | tee $LOG
	else
		# Edit cluster spec before deploying
		[ -n "$_EDIT" ] && vim $CLUSTER_SPEC
		eksctl create cluster -f $CLUSTER_SPEC | tee $LOG
	fi
	local ret=$?
	if [ $ret -eq 0 ]; then
		local end=$(date +%s)
		printf "\nTime: $((end-start)) seconds\n" | tee -a $LOG
		prompt_info "\nTo use your cluster, run the following:"
		prompt_info "export KUBECONFIG=$KUBECONFIG\nexport AWS_PROFILE=$PROFILE"
	else
		prompt_error "failed to deploy cluster"
	fi

	return $ret
}


# Delete EKS cluster
delete_cluster() {
	if [ -z "$CLUSTER_SPEC" ]; then
		LOG+=_eks_shutdown.log
	else
		LOG+=_${NAME}_shutdown.log
	fi
	local start=$(date +%s)
	eksctl delete cluster --name $NAME --region $REGION | tee $LOG
	local ret=$?
	if [ $ret -eq 0 ]; then
		local end=$(date +%s)
		printf "\nTime: $((end-start)) seconds\n" | tee -a $LOG
	else
		prompt_error "Encountered an issue deleting cluster"
	fi

	return $ret
}


# Check for script dependencies
# if ! install_dependencies; then
# 	prompt_error "failed to install script dependencies"
# 	exit 1
# fi

# Verify eks user has been created
if ! create_eks_iam_user; then
	prompt_error "failed to generate $PROFILE user"
	exit 1
fi

export AWS_PROFILE=$PROFILE

# Check for user input
while [ -n "$1" ]; do
	case $1 in
		-d|--delete)
			DELETE=true
			shift
		;;
		-e|--edit)
			_EDIT=1
			shift
		;;
		-f|--filename)
			if [[ -z "$2" || ! -f "$2" ]]; then
				prompt_error "a cluster specification file must be passed with this option"
				usage
				exit 1
			fi
			CLUSTER_SPEC="$2"
			NAME=$(echo $2 | sed 's|.*/\(.*\)\.yml|\1|')
			export KUBECONFIG=$HOME/.kube/eksctl/clusters/$NAME
			shift
			shift
		;;
		-h|--help)
			usage
			exit
		;;
		-s|--suffix)
			SUFFIX="$2"
			LOG_DIR+="/${SUFFIX}"
			shift
			shift
		;;
		*)
			prompt_error "invalid argument!"
			usage
			exit 1
		;;
	esac
done

mkdir -p $LOG_DIR
LOG=$LOG_DIR/$(date +"%Y-%m-%d_%H-%M-%S")

if [ -n "$DELETE" ] && $DELETE; then
	delete_cluster
else
	# Create a k8s cluster on AWS EKS
	create_custer
fi
ret=$?
prompt_info "\nLog can be found here: $LOG"
exit $ret