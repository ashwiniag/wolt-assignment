eks_cluster_name := alice-saitama-dragon
region := ap-south-1
kubeconfig_dir := /tmp/kubeconfig

create_kubeconfig_dir: 
	mkdir -p ${kubeconfig_dir}

kubeconfig: create_kubeconfig_dir 
	rm -f ${kubeconfig_dir}/prometheus-operator; aws eks --region ${region} update-kubeconfig --name ${eks_cluster_name} --kubeconfig ${kubeconfig_dir}/prometheus-operator

list: kubeconfig
	kubectl get pods --kubeconfig ${kubeconfig_dir}/prometheus-operator --namespace default | grep prometheus-operator

apply: kubeconfig
	kubectl apply -f bundle.yaml -f prometheus-rbac.yaml -f prometheus-service.yaml   --kubeconfig ${kubeconfig_dir}/prometheus-operator
	kubectl apply -f prometheus.yaml -f service-monitor.yaml -f pod-monitor.yaml
destroy: kubeconfig
	 kubectl delete -f pod-monitor.yaml -f service-monitor.yaml -f prometheus.yaml -f prometheus-service.yaml -f prometheus-rbac.yaml -f bundle.yaml --kubeconfig ${kubeconfig_dir}/prometheus-operator
