#!/bin/bash

set -euo pipefail
set -x

current_dir=$PWD

usage="(Not an idempotent script - draft1) run => provisioning_script.sh plan|apply|delete."

declare -r command=${1:?}

function check_aws_profile() {
	if [ -z "$(aws sts get-caller-identity)" ]; then echo "ERROR: export AWS_PROFILE"; else echo "aws aws profile found proceeding to artefact_build_upload"; fi
}

function artefact_build_upload() {
	# In directory  nginx-golang-mysql
	if [ -z "$(aws ecr describe-repositories | jq '.repositories[].repositoryName' | grep -o "alice-application")" ]; then
		repositoryUri=$(aws ecr create-repository --repository-name alice-application --region ap-south-1 | jq '.repository.repositoryUri' | tr -d '"')
	fi

	cd $current_dir/nginx-golang-mysql/backend/
	docker build -t $(aws ecr describe-repositories | jq '.repositories[].repositoryUri' | grep alice-application | sed 's!\"!!g'):latest -f Dockerfile .
	aws ecr get-login-password | docker login --username AWS --password-stdin  $(aws ecr describe-repositories | jq '.repositories[].repositoryUri' | grep alice-application | sed 's!\"!!g' | awk -F "." '{print $1}').dkr.ecr.ap-south-1.amazonaws.com
	docker push $(aws ecr describe-repositories | jq '.repositories[].repositoryUri' | grep alice-application | sed 's!\"!!g')
	echo "INFO: uploaded artefact"

}


function backend_s3_tf() {
	# In directory  tfstate_setup
	if [ -z "$(aws s3api list-buckets | jq '.Buckets[].Name' | grep -o "wolt-assignment-alice-team")" ]; then
		cd $current_dir/tfstate_setup/
		terraform init
		terraform apply -auto-approve
		echo "INFO: backend_created"
	fi

	echo "INFO: backend_exsist"

}

function all_layers() {
	# In directory  tfstate_setup if apply or delete
	cd $current_dir/alice-team/infra
	echo yes | make apply

	cd $current_dir/alice-team/resources
	make kubeconfig
	echo yes | make apply

	cd $current_dir/alice-team/services_k8s
	make kubeconfig
	echo yes | make apply

	cd $current_dir/alice-team/setup_metrics/kube-state-metrics-configs
	make kubeconfig
	make apply

	cd $current_dir/alice-team/setup_metrics/prometheus-operator
	make kubeconfig
	set -e
	make apply
	if [ $? != 0 ]; then
	    make apply
	fi


}

function delete_all_provisioned() {
#	# all_layers and backend_s3_tf and ecr too
	cd $current_dir/alice-team/setup_metrics/prometheus-operator
	make kubeconfig
	make destroy

	cd $current_dir/alice-team/setup_metrics/kube-state-metrics-configs
	make kubeconfig
	make destroy

	cd $current_dir/alice-team/resources
	make kubeconfig
	echo yes | make destroy

	cd $current_dir/alice-team/services_k8s
	make kubeconfig
	echo yes | make destroy

	cd $current_dir/alice-team/infra
	echo yes | make destroy

	cd $current_dir/tfstate_setup/
	terraform destroy -auto-approve

}


case $command in
    "apply") check_aws_profile
    				 artefact_build_upload
    				 backend_s3_tf
    				 all_layers
           ;;
#    "plan") check_aws_profile
#           ;;
    "delete") delete_all_provisioned
esac