eks_cluster_name := alice-saitama-dragon
region := ap-south-1
kubeconfig_dir := /tmp/kubeconfig

## To be able to fetch Cluster metrics.

create_kubeconfig_dir:
	mkdir -p ${kubeconfig_dir}

kubeconfig: create_kubeconfig_dir
	rm -f ${kubeconfig_dir}/kube-state-metrics; aws eks --region ${region} update-kubeconfig --name ${eks_cluster_name} --kubeconfig ${kubeconfig_dir}/kube-state-metrics

list: kubeconfig
	kubectl get deployments kube-state-metrics -n kube-system --kubeconfig ${kubeconfig_dir}/kube-state-metrics

apply: kubeconfig
	kubectl apply -f . --kubeconfig ${kubeconfig_dir}/kube-state-metrics

destroy: kubeconfig
	kubectl delete -f . --kubeconfig ${kubeconfig_dir}/kube-state-metrics
