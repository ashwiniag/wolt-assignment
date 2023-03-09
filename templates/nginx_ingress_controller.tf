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

}
