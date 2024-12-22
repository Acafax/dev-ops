# resource "kubernetes_secret_v1" "mysql-secret" {
#   metadata {
#     name = "mysql-pass"
#     namespace = kubernetes_namespace.demo_app_ns.metadata.0.name
#   }
#
#   data = {
#     mysql-root-password = "cm9vdHBhc3N3b3Jk"
#     mysql-user-password = "dXNlcnBhc3N3b3Jk"
#   }
# }