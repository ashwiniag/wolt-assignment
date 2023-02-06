////provider "helm" {
////  kubernetes {
////    host                   = data.aws_eks_cluster.host.endpoint
////    cluster_ca_certificate = base64decode(data.aws_eks_cluster.host.certificate_authority[0].data)
////    exec {
////      api_version = "client.authentication.k8s.io/v1beta1"
////      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name]
////      command     = "aws"
////    }
////  }
////}
////
////resource "helm_release" "nginx-ingress-controller" {
////  name       = "nginx-ingress-controller"
////  repository = "https://charts.bitnami.com/bitnami"
////  chart      = "nginx-ingress-controller"
////
////
////  set {
////    name  = "service.type"
////    value = "LoadBalancer"
////  }
////
////}
////
//data "kubernetes_service" "ingress_nginx" {
//
//  metadata {
//    name      = "nginx-ingress-controller"
//    namespace = "default"
//  }
//  depends_on = [
//    helm_release.ingress-nginx
//  ]
//}
//
////output "k8s_service_ingress_lb" {
////  description = "External DN of load balancer"
////  value       = data.kubernetes_service.ingress_nginx.status.0.load_balancer.0.ingress.0.hostname
////
////}
//
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.host.endpoint
    #    token              = local.eks_certificate_url
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.host.certificate_authority[0].data)
    config_path = "/tmp/kubeconfig/alice-saitama/services"
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name]
      command     = "aws"
    }
    # load_config_file       = false
  }
}

resource "helm_release" "ingress-nginx" {
  name      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  version    = "3.8.0"

//    set {
//      name  = "defaultBackend.enabled"
//      value = "false"
//    }
//
//  set {
//    name = "serviceAccount.automountServiceAccountToken"
//    value = "true"
//  }
}
