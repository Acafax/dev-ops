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
    }
  }

}
# resource "kubernetes_namespace_v1" "app-data-base" {
#   metadata {
#     name = "my-data-base"
#     labels = {
#       "origin" = "terraform"
#       "app" = "database"
#     }
#   }
# }
# resource "kubernetes_namespace_v1" "app-front-end" {
#   metadata {
#     name = "my-front-end"
#     labels = {
#       "origin" = "terraform"
#       "app" = "frontend"
#     }
#   }
# }
#ConfigMapa dla MySQL-a
resource "kubernetes_config_map" "app-config-map" {
  metadata {
    name = "mysql-config-ma"
    namespace = "kubernetes_namespace_v1.app-spring.metadata.0.name"
  }
  data = {
    host = "localhost"
    port = "3306"
    name_db = "new_schema"
  }
}


#Secret dla MySQL
resource "kubernetes_secret_v1" "mysql-secret" {
  metadata {
    name      = "mysql-secret-pass"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
  }
  data = {
    username = "cm9vdA=="
    password = "d2lrdG9y"
  }
}
#Serwis dla MYSQLa
resource "kubernetes_service" "app-mysql-service" {
  metadata {
    name = "mysql-applikacja"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
    labels = {
      app = "mysql-app"
    }
  }

  spec {
    selector = {
      app  = kubernetes_stateful_set.mysql.metadata.0.labels.app
      tier = "mysql"
    }

    port {
      port = 3306
    }

    cluster_ip = "None"
  }
}
resource "kubernetes_persistent_volume_claim" "app-pvc" {
  metadata {
    name = "mysql-pvc"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
    labels = {
      app = "mysql-app"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}
resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name = "mysql"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
    labels = {
      app = "mysql"
    }
  }
  spec {
    replicas = 1
    service_name = "mysql-applikacja"

    selector {
      match_labels = {
        app="mysql"
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
          image = "mysql:8.0.40"

          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "kubernetes_secret_v1.mysql-secret.metadata[0].name"
                key  = "password"
              }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = "kubernetes_secret_v1.mysql-secret.metadata[0].name"
                key  = "username"
              }
            }
          }
          port {
            container_port = 3306
          }
          volume_mount {
            mount_path = "/var/lib/mysql"
            name       = "mysql-data"
          }
        }
        volume {
          name = "mysql-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.app-pvc.metadata[0].name
          }
        }
      }
    }
  }
}


#
# # StatefulSet dla MySQL
# resource "kubernetes_stateful_set" "mysql" {
#   metadata {
#     name      = "mysql"
#     namespace = kubernetes_namespace_v1.app-data-base.metadata[0].name
#   }
#   spec {
#     replicas = 1
#     service_name = "mysql"
#     selector {
#       match_labels = {
#         app = "mysql"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "mysql"
#         }
#       }
#       spec {
#         container {
#           name  = "mysql"
#           image = "mysql:latest"
#           env {
#             name = "MYSQL_ROOT_PASSWORD"
#             value_from {
#               secret_key_ref {
#                 name = kubernetes_secret_v1.mysql-secret.metadata[0].name
#                 key  = "password"
#               }
#             }
#           }
#           port {
#             container_port = 3306
#           }
#           volume_mount {
#             name       = "mysql-data"
#             mount_path = "/var/lib/mysql"
#           }
#         }
#       }
#     }
#     volume_claim_template {
#       metadata {
#         name = "mysql-data"
#       }
#       spec {
#         access_modes = ["ReadWriteOnce"]
#         resources {
#
#         }
#       }
#     }
#   }
# }

# Deployment dla Spring Java
resource "kubernetes_deployment_v1" "spring" {
  metadata {
    name      = "spring-app"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
    labels = {
      "app" = "applikacja-spring"
    }
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
          image = "acafax/spring-docker-app:latest" # NAZWA OBRAZU Ze SPRING

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
resource "kubernetes_ingress_v1" "web-server-ingress" {
  metadata {
    name = "web-server-ingress"
    namespace = kubernetes_namespace_v1.app-spring.metadata[0].name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "web-server.tf.npi-cluster"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.spring-app-service.metadata[0].name
              port {
                name = "http"
              }
            }
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
