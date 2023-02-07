# -------------------outputs----------------

# -------------------variables--------------
locals {
  backeend_name = "backend"
  namespace = "backend-applications"

}

//variable namespace {}

variable "backend_app" {
  type = map(string)
  default = {
    port                = "8000"
    count               = "1"
//    request_cpu       = "100m"
//    request_ram       = "300Mi"
//    limit_cpu         = "200m"
//    limit_ram         = "400Mi"
  }
}

# -------------------resources--------------

resource "kubernetes_namespace" "backend_app" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_deployment" "backend_app" {

  metadata {
    name      = "${local.backeend_name}-deployment"
    namespace = local.namespace
    labels = {
      app = local.backeend_name
      wolt = "true"
    }
  }

  spec {
    replicas = var.backend_app.count

    selector {
      match_labels = {
        app = local.backeend_name
        wolt = "true"
      }
    }

    template {
      metadata {
        labels = {
          app = local.backeend_name
          wolt = "true"
        }
      }

      spec {
        restart_policy = "Always"

        node_selector = {
          group = "common_node"
        }

        container {
          image             = "024662722948.dkr.ecr.ap-south-1.amazonaws.com/alice-application" //*
          name              = local.backeend_name
          image_pull_policy = "Always"
          // For testing scope disabling this.
//          resources {
//            requests = {
//              cpu               = var.backend_app.request_cpu
//              memory            = var.backend_app.request_ram
//            }
//
//            limits = {
//              cpu               = var.backend_app.limit_cpu
//              memory            = var.backend_app.limit_ram
//            }
//          }

          env {
            name  = "DB_HOST"
            value = "${local.dbname}-svc.${local.namespace}.svc.cluster.local"
          }

          env {
            name  = "DB_PASSWORD"
            value = kubernetes_secret.db-secret.data.db-password
          }

          env {
            name  = "DB_PORT"
            value = var.db_app.service_port
          }

          port {
            name           = "metrics"
            container_port = var.backend_app.port
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend_app_service" {
  metadata {
    name      = "${local.backeend_name}-svc"
    namespace = local.namespace
    labels = {
      app = local.backeend_name
      wolt = "true"
    }
  }

  spec {
    selector = {
      app = local.backeend_name
      wolt = "true"
    }

    port {
      name        = "metrics"
      port        = 80
      target_port = var.backend_app.port
    }
  }
}

