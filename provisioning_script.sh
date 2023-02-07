#!/bin/bash

set -euo pipefail
set -x

# Caution: This script can further be enhanced. The aim was to use script for
# quick local testing purpose.

current_dir=$PWD

usage="(version1) run => provisioning_script.sh apply|delete."

declare -r command=${1:?}

function check_aws_profile() {
	# To detect aws profile to use.
	if [ -z "$(aws sts get-caller-identity)" ]; then echo "ERROR: export AWS_PROFILE"; else echo "aws aws profile found proceeding to artefact_build_upload"; fi
}

function artefact_build_upload() {
	# In directory  nginx-golang-mysql, Dockerizes the application and uploads in AWS ECR through aws cli
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
	# In directory  tfstate_setup, creates S3 and dynamodb to store terraform statefiles and takes care of state locking.
	# if [ -z "$(aws s3api list-buckets | jq '.Buckets[].Name' | grep "wolt-assignment-alice-team")" ] && [ "$(aws dynamodb describe-table --table-name tfstate &> /dev/null; echo $?)" -ne 0 ]; then
	if [ -z "$(aws s3api list-buckets | jq '.Buckets[].Name' | grep -o "wolt-assignment-alice-team")" && "$(aws dynamodb describe-table --table-name tfstate)" ]; then
		cd $current_dir/tfstate_setup/
		terraform init
		terraform apply -auto-approve
		echo "INFO: backend_created"
	fi

	echo "INFO: backend_exsist"

}

function all_layers() {
	# In directory  tfstate_setup,  provisions complete stack in layers.
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
	make apply

	# Updates URL of the LB in prometheus.yaml file for remote_write to Victoriamterics endpoint.
	echo "Updating remote_write endpoint in prometheus.yaml, verify once"
	cd $current_dir/alice-team/setup_metrics/prometheus-operator
  URL=$(kubectl get svc -n default -o json | jq '.items[].status.loadBalancer.ingress[0].hostname' | head -n 1)
	sed -i -E "s/url:.*/url: $URL\/api\/v1\/write\//" prometheus.yaml
}

function delete_all_provisioned() {
#	# all_layers and backend_s3_tf and ecr too
	cd $current_dir/alice-team/setup_metrics/prometheus-operator
	make kubeconfig
	make destroy

	cd $current_dir/alice-team/setup_metrics/kube-state-metrics-configs
	make kubeconfig
	make destroy

	cd $current_dir/alice-team/services_k8s
	make kubeconfig
	echo yes | make destroy

	cd $current_dir/alice-team/resources
	make kubeconfig
	echo yes | make destroy

	cd $current_dir/alice-team/infra
	echo yes | make destroy

	cd $current_dir/tfstate_setup/
	aws s3api delete-objects --bucket wolt-assignment-alice-team --delete "$(aws s3api list-object-versions --bucket "wolt-assignment-alice-team" --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" > /dev/null
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
