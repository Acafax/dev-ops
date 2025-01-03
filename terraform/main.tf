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
resource "kubernetes_namespace_v1" "app_spring_namespace" {
  metadata {
    name = "app-spring"
    labels = {
      "origin" = "terraform"
    }
  }
}

resource "kubernetes_pod_v1" "spring_pod" {
  metadata {
    name = "spring-pod"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
  }
  spec {
    container {
      name = "spring-pod"
      image = "busybox:1.37.0"
      command = ["/bin/sh", "-c"]
      args = ["while true; do echo \"hello from busybox\"; sleep 2; done"]
      resources {
        requests = {
          "cpu" = "100m",
          "memory" = "100Mi"
        }
        limits = {
          "cpu" = "1000m",
          "memory" = "256Mi"
        }
      }
    }
  }
}

#ConfigMapa dla MySQL-a
resource "kubernetes_config_map" "mysql_config_map" {
  metadata {
    name = "mysql-config-map"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
  }
  data = {
    host = "app-mysql-service"
    port = "3306"
    name_db = "new_schema"
  }
}


#Secret dla MySQL
resource "kubernetes_secret_v1" "mysql_secret" {
  metadata {
    name      = "mysql-secret-pass"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
  }
  data = {
    username = "cm9vdA=="
    password = "d2lrdG9y"
  }
}

#Serwis dla MYSQLa
resource "kubernetes_service" "app_mysql_service" {
  metadata {
    name = "app-mysql-service"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
    labels = {
      app = "mysql-app"
    }
  }

  spec {
    selector = {
      app  = kubernetes_stateful_set.mysql_stateful_set.metadata.0.labels.app
      tier = "mysql"
    }

    port {
      name = "http"
      protocol = "TCP"
      port = 3306
      target_port = 3306
    }

    cluster_ip = "None"
  }
}
resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name = "mysql-pvc"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
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
resource "kubernetes_stateful_set" "mysql_stateful_set" {
  metadata {
    name = "mysql-stateful-set"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
    labels = {
      app = "mysql"
    }
  }
  spec {
    replicas = 1
    service_name = "app-mysql-service" // to bez zmian

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
          name  = "mysql-container"
          image = "mysql:8.0.40"

          env {
            name = "MYSQL_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.mysql_config_map.metadata[0].name
                key = "host"
              }
            }
          }
          env {
            name = "MYSQL_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.mysql_config_map.metadata[0].name
                key = "port"//kubernetes_config_map.mysql_config_map.data.port
              }
            }
          }
          env {
            name = "MYSQL_DATABASE"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.mysql_config_map.metadata[0].name
                key = "name_db"//kubernetes_config_map.mysql_config_map.data.name_db
              }
            }
          }
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql_secret.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mysql_secret.metadata[0].name
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
            claim_name = kubernetes_persistent_volume_claim.mysql_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# # Deployment dla Spring Java
 resource "kubernetes_deployment_v1" "spring_deployment" {
   depends_on = [kubernetes_stateful_set.mysql_stateful_set]

   metadata {
     name      = "spring-app"
     namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
     labels = {
       "app" = "applikacja-spring"
     }
   }
   spec {
     replicas = 2
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
         container {
           name  = "spring-app"
           image = "acafax/spring-app:latest" # NAZWA OBRAZU Ze SPRINGA

           env {
             name = "MYSQL_HOST"
             value_from {
               config_map_key_ref {
                 name = kubernetes_config_map.mysql_config_map.metadata[0].name
                 key  = "host"//kubernetes_config_map.mysql_config_map.data.host
               }
             }
           }
           env {
             name = "MYSQL_PORT"
             value_from {
               config_map_key_ref {
                 name = kubernetes_config_map.mysql_config_map.metadata[0].name
                 key  = "port"//kubernetes_config_map.mysql_config_map.data.port
               }
             }
           }
           env {
             name = "MYSQL_DB_NAME"
             value_from {
               config_map_key_ref {
               name = kubernetes_config_map.mysql_config_map.metadata[0].name
                 key  = "name_db"//kubernetes_config_map.mysql_config_map.data.name_db
               }
             }
           }
           env {
             name = "MYSQL_USER"
             value_from {
               secret_key_ref {
                 name = kubernetes_secret_v1.mysql_secret.metadata[0].name
                 key  = "username"
               }
             }
           }
           env {
             name = "MYSQL_ROOT_PASSWORD"
             value_from {
               secret_key_ref {
                 name = kubernetes_secret_v1.mysql_secret.metadata[0].name
                 key  = "password"
               }
             }
           }
           command = ["java"]
           args = ["-jar", "./target/dev-ops-app.jar"]

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
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
  }
  spec {
    selector = {
      "app" = "spring-app"
    }
    port {
      name = "http"
      protocol = "TCP"
      port = 80
      target_port = 8080
    }
  }
}