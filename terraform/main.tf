provider "minikube" {
  kubernetes_version = "v1.25.0"
}

resource "minikube_cluster" "docker" {
  driver       = "docker"
  cluster_name = "spring-cluster"
  cni          = "bridge"
  addons = [
    "default-storageclass",
    "storage-provisioner",
    "ingress",
    "ingress-dns",
    "dashboard"
  ]
}

provider "kubernetes" {
  host = minikube_cluster.docker.host

  client_certificate     = minikube_cluster.docker.client_certificate
  client_key             = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
}

# Namespace
resource "kubernetes_namespace_v1" "app-spring" {
  metadata {
    name = "my-spring"
    labels = {
      "origin" = "terraform"
      "app" = "spring"
    }
  }

}
resource "kubernetes_namespace_v1" "app-data-base" {
  metadata {
    name = "my-data-base"
    labels = {
      "origin" = "terraform"
      "app" = "database"
    }
  }
}
resource "kubernetes_namespace_v1" "app-front-end" {
  metadata {
    name = "my-front-end"
    labels = {
      "origin" = "terraform"
      "app" = "frontend"
    }
  }
}

# Secret dla MySQL
resource "kubernetes_secret_v1" "mysql-secret" {
  metadata {
    name      = "mysql-secret"
    namespace = kubernetes_namespace_v1.app-data-base.metadata[0].name
  }
  data = {
    host = base64encode("localhost")
    port = base64encode("3306")
    name_db = base64encode("new_schema")
    username = base64encode("root")
    password = base64encode("wiktor")
  }
}

# StatefulSet dla MySQL
resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace_v1.app-data-base.metadata[0].name
  }
  spec {
    replicas = 1
    service_name = "mysql"
    selector {
      match_labels = {
        app = "mysql"
      }
    }
    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }
      spec {
        container {
          name  = "mysql"
          image = "mysql:latest"
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "password"
              }
            }
          }
          port {
            container_port = 3306
          }
          volume_mount {
            name       = "mysql-data"
            mount_path = "/var/lib/mysql"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "mysql-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {

        }
      }
    }
  }
}

# Deployment dla Spring Java
resource "kubernetes_deployment_v1" "spring" {
  metadata {
    name      = "spring-app"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "spring-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "spring-app"
        }
      }
      spec {
        init_container {
          name = "czekaj-na-bd"
          image = "busybox:1.35"
          command = ["sh", "-c", "until nc -z mysql 3306; do echo czekam na bd; sleep 2; done;"]
        }
        container {
          name  = "spring-app"
          image = "dev-ops-app:latest" # NAZWA OBRAZU Ze SPRING

          env {
            name = "MYSQL_HOST"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "host"
              }
            }
          }
          env {
            name = "MYSQL_PORT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "port"
              }
            }
          }
          env {
            name = "MYSQL_DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "name_db"
              }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql-secret.metadata[0].name
                key  = "password"
              }
            }
          }
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}


resource "kubernetes_service_v1" "spring-app-service" {
  metadata {
    name = "spring-app-service"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
  }
  spec {
    selector = {
      "app" = "spring-app"
    }
    port {
      name = "http"
      protocol = "TCP"
      port = 80
      target_port = "http"
    }
  }
}
#
# # Deployment dla Frontendu
# resource "kubernetes_deployment" "frontend" {
#   metadata {
#     name      = "frontend-app"
#     namespace = kubernetes_namespace.app_front_end.metadata[0].name
#   }
#   spec {
#     replicas = 1
#     selector {
#       match_labels = {
#         app = "frontend-app"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "frontend-app"
#         }
#       }
#       spec {
#         container {
#           name  = "frontend-app"
#           image = "my-frontend-app:latest" # Twój obraz Dockera
#           port {
#             container_port = 80
#           }
#         }
#       }
#     }
#   }
# }
# # Ingress dla Frontendu
#
# resource "kubernetes_ingress" "frontend_ingress" {
#   metadata {
#     name      = "frontend-ingress"
#     namespace = kubernetes_namespace.app_front_end.metadata[0].name
#     # annotations = {
#     #   "nginx.ingress.kubernetes.io/rewrite-target" = "/"
#     # }
#   }
#   spec {
#     rules {
#       host = "frontend.example.com"
#       http {
#         paths {
#           path    = "/"
#           backend {
#             service_name = kubernetes_service.frontend.metadata[0].name
#             service_port = 80
#           }
#         }
#       }
#     }
#   }
# }
#
# # Service dla Frontendu
# resource "kubernetes_service" "frontend" {
#   metadata {
#     name      = "frontend-service"
#     namespace = kubernetes_namespace.app_front_end.metadata[0].name
#   }
#   spec {
#     selector = {
#       app = "frontend-app"
#     }
#     port {
#       protocol = "TCP"
#       port     = 80
#       target_port = 80
#     }
#     type = "ClusterIP"
#   }
# }
