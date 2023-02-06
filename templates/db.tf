resource "kubernetes_secret" "db-secret" {
  metadata {
    name = "db-secret"
    namespace = local.namespace
  }

  data = {
    "db-password" = base64encode("db-q5n2g")
  }
}


# -------------------outputs----------------

# -------------------variables--------------
locals {
  dbname = "db"

}

variable "db_app" {
  type = map(string)
  default = {
    port                = "3306"
    count               = "1"
    version             = "8"
    service_port        = "86"
  }
}

# -------------------resources--------------

resource "kubernetes_deployment" "db" {

  metadata {
    name      = "${local.dbname}-deployment"
    namespace = local.namespace
    labels = {
      app = local.dbname
    }
  }

  spec {
    replicas = var.db_app.count

    selector {
      match_labels = {
        app = local.dbname
      }
    }

    template {
      metadata {
        labels = {
          app = local.dbname
        }
      }

      spec {
        restart_policy = "Always"

        node_selector = { //*  common_node
          group = "common_node"
        }

        container {
          image             = "mysql:${var.db_app.version}"
          name              = local.dbname
          image_pull_policy = "Always"

          env {
            name  = "MYSQL_DATABASE"
            value = "example"
          }
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value = kubernetes_secret.db-secret.data.db-password
          }
//          volume_mount { //*
//            name      = "db-secret"
//            mount_path = "/run/secrets"
//            read_only = true
//          }
//          volume_mounts = [
//            {
//              name = "db-data"
//              mount_path = "/var/lib/mysql"
//            }
//          ]
//          volume {
//            name = "db-secret"
//            secret {
//              secret_name = "db-secret"
//            }
//          }

          args = [
            "--default-authentication-plugin=mysql_native_password" //*
          ]

          port {
            name           = "db-app"
            container_port = var.db_app.port
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "db_app_service" {
  metadata {
    name      = "${local.dbname}-svc"
    namespace = local.namespace
    labels = {
      app = local.dbname
    }
  }

  spec {
    selector = {
      app = local.dbname
    }

    port {
      name        = "db"
      port        = var.db_app.service_port
      target_port = var.db_app.port
    }
  }
}



