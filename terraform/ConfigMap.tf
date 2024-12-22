# resource "kubernetes_config_map" "demo_app_cm" {
#   metadata {
#     name = "mysql-config-map"
#     namespace = kubernetes_namespace_v1.app-spring.metadata.0.name
#   }
#
#   data = {
#     mysql-server        = "localhost"
#     mysql-database-name = "new_schema"
#     mysql-user-username = "root"
#   }
# }
