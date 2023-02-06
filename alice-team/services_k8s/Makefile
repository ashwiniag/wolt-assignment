host_infra := alice-saitama
kubeconfig_dir = /tmp/kubeconfig/${host_infra}
kubeconfig_path = ${kubeconfig_dir}/services

clean:
	for i in $$(find -L . -xtype l); do unlink $$i; done

links: clean
	ln -s ../../templates/remote_state.tf .
	ln -s ../../templates/provider.tf .
	ln -s ../../templates/k8s_provider.tf .
	ln -s ../../templates/vm_metrics.tf .
	ln -s ../../templates/nginx_ingress_controller.tf . # //*
	ln -s ../../templates/nginx-ingress.tf .
	ln -s ../../templates/backend.tf .
	ln -s ../../templates/db.tf .
	#ln -s ../../templates/vm_agent.tf

init: links
	terraform init -backend-config="key=terraform/${host_infra}/services/terraform.tfstate"

create_kubeconfig_dir:
	mkdir -p ${kubeconfig_dir}

kubeconfig: create_kubeconfig_dir
	rm -rf ${kubeconfig_path}; aws eks --region ap-south-1 update-kubeconfig --name alice-saitama-dragon --kubeconfig ${kubeconfig_path}

plan: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform plan

apply: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform apply

destroy: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform destroy

