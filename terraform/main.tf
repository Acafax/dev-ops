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


resource "kubernetes_config_map" "mysql_config_map" {
  metadata {
    name = "mysql-config-map"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
  }
  data = {
    mysql-server = "applikacja-mysql-app.app-spring.svc.cluster.local"
    port = "3306"
    name_db = "new_schema"
  }
}

resource "kubernetes_secret" "mysql_secret" {
  metadata {
    name      = "mysql-secret-pass"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
  }
  data = {
    username = "user"
    password = "wiktor"
  }
}

resource "kubernetes_service" "app_mysql_service" {
  metadata {
    name = "applikacja-mysql-app"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
    labels = {
      app = "applikacja-mysql"
    }
  }
  spec {
    selector = {
      //app  = kubernetes_stateful_set.mysql_stateful_set.metadata.0.labels.app
      //app  = kubernetes_deployment.mysql_deployment.metadata.0.labels.app
      app = "mysql"
    }

    port {
      port = 3306
      target_port = 3306
    }
    //cluster_ip = "None" // do wywalenia
  }
}

resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name = "mysql-pvc" //mysql-pvc
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
    labels = {
      app = "applikacja-mysql" //mysql-app
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
    name = "applikacja-mysql-app"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata[0].name
    labels = {
      app = "applikacja-mysql"
      tier = "baza-danych"
    }
  }
  spec {
    replicas = 1
    service_name = "applikacja-mysql-app" // to bez zmian

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
            name = "DB_SERVER" //
            value = "applikacja-mysql-app.app-spring.svc.cluster.local"
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
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "password"
              }
              # secret_key_ref {
              #   key  = "password"
              #   name = kubernetes_secret.mysql_secret.metadata.0.name
              #
              # }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
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
resource "kubernetes_service" "spring_app_service" {

  depends_on = [kubernetes_deployment.spring_deployment]
  metadata {
    name = "aplikacja-spring-app"
    namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
    labels = {
      app = "spring-app"
    }
  }
  spec {
    ///type = "NodePort"
    selector = {
      app = "spring-app"
    }
    port {
      name = "http"
      protocol = "TCP"
      port = 80
      target_port = "http"
    }
  }
}

 resource "kubernetes_deployment" "spring_deployment" {
   depends_on = [kubernetes_stateful_set.mysql_stateful_set]
   //depends_on = [kubernetes_deployment.mysql_deployment]

   metadata {
     name      = "aplikacja-spring-app"
     namespace = kubernetes_namespace_v1.app_spring_namespace.metadata.0.name
     labels = {
       "app" = "spring-app"
     }
   }
   spec {
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
           name  = "spring-app-deploy"
           image = "acafax/spring-app:latest" # NAZWA OBRAZU Ze SPRINGA

           port {
             name = "http"
             container_port = 8080
           }

           resources {
             limits = {
               cpu = 1
               memory = "1Gi"
             }
           }

           env {
             name = "DB_PASSWORD"
             value_from {
               secret_key_ref {
                 key  = "password"
                 name = kubernetes_secret.mysql_secret.metadata.0.name

               }
             }
           }
           env {
             name = "DB_SERVER"
             value_from {
               config_map_key_ref {
                 key  = "mysql-server"
                 name = kubernetes_config_map.mysql_config_map.metadata[0].name
               }
             }
           }
           env {
             name = "DB_PORT"
             value_from {
               config_map_key_ref {
                 key  = "port"
                 name = kubernetes_config_map.mysql_config_map.metadata[0].name
               }
             }
           }
           env {
             name = "DB_NAME"
             value_from {
               config_map_key_ref {
                 key  = "name_db"
                 name = kubernetes_config_map.mysql_config_map.metadata[0].name
               }
             }
           }
           env {
             name = "DB_USERNAME"
             value_from {
               secret_key_ref {
                 name = kubernetes_secret.mysql_secret.metadata[0].name
                 key  = "username"
               }
             }
           }

           command = ["java"]
           args = ["-jar", "./target/dev-ops-app.jar"]
         }
         image_pull_secrets {
           name = kubernetes_secret.mysql_secret.metadata.0.name
         }
       }
     }
   }
 }
