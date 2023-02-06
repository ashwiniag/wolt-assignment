resource "kubernetes_ingress_v1" "ingress" {
  wait_for_load_balancer = true
  metadata {
    name = "ingress-nginx"
    namespace = local.namespace
  }
  depends_on = [
   helm_release.ingress-nginx
  ]

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        path {
          backend {
            service {
              name = kubernetes_service.backend_app_service.metadata.0.name
              port {
                number = 80
              }
            }
          }
          path = "/backend"
        }
        path {
          backend {
            service {
              name = kubernetes_service.backend_app_service.metadata.0.name
              port {
                number = 80
              }
            }
          }
          path = "/backend_metrics"
        }
      }
    }

  }
}

resource "kubernetes_ingress_v1" "vm-ingress" {
  wait_for_load_balancer = true
  metadata {
    name = "vm-ingress-nginx"
    namespace = local.name

  }
  depends_on = [
    helm_release.ingress-nginx
  ]

  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          backend {
            service {
              name = kubernetes_service.vm_metrics_service.metadata.0.name
              port {
                number = 88
              }
            }
          }
          path = "/"
        }
      }
    }

  }
}