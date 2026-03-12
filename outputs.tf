# Mandatory output block for weaviate module
output "vector_output" {
  description = "Weaviate module output component asset for external consumption"
  value = {
    namespace              = kubernetes_namespace_v1.weaviate.metadata[0].name
    service_name           = "${var.helm_release_name}-weaviate"
    service_dns            = "${var.helm_release_name}-weaviate.${kubernetes_namespace_v1.weaviate.metadata[0].name}.svc.cluster.local"
    service_endpoint       = "http://${var.helm_release_name}-weaviate.${kubernetes_namespace_v1.weaviate.metadata[0].name}.svc.cluster.local:7000"
    grpc_endpoint          = "${var.helm_release_name}-weaviate.${kubernetes_namespace_v1.weaviate.metadata[0].name}.svc.cluster.local:50051"
    replicas               = var.weaviate_replicas
    storage_size           = var.storage_size
    storage_type           = var.storage_type
    vector_dimensions      = var.vector_dimensions
    helm_release_name      = var.helm_release_name
    api_key_secret_name    = var.create_api_key ? aws_secretsmanager_secret.weaviate_api_key[0].name : null
    api_key_secret_arn     = var.create_api_key ? aws_secretsmanager_secret.weaviate_api_key[0].arn : null
    backup_bucket_name     = var.enable_s3_backups ? aws_s3_bucket.weaviate_backups[0].id : null
    backup_bucket_arn      = var.enable_s3_backups ? aws_s3_bucket.weaviate_backups[0].arn : null
    irsa_role_arn          = aws_iam_role.weaviate_irsa.arn
    irsa_role_name         = aws_iam_role.weaviate_irsa.name
    cluster_name           = local.cluster_name
    cluster_region         = local.region
    admin_users            = var.weaviate_admin_users
    readonly_users         = var.weaviate_readonly_users
  }
}

# Mandatory report block for platform reporting
output "mpp_report" {
  description = "This is the string key-value map containing properties presented to the user for consuming this component."
  value = {
    "Weaviate Namespace"       = kubernetes_namespace_v1.weaviate.metadata[0].name
    "Service Name"             = "${var.helm_release_name}-weaviate"
    "Service Endpoint (REST)"  = "http://${var.helm_release_name}-weaviate.${kubernetes_namespace_v1.weaviate.metadata[0].name}.svc.cluster.local:7000"
    "Service Endpoint (gRPC)"  = "${var.helm_release_name}-weaviate.${kubernetes_namespace_v1.weaviate.metadata[0].name}.svc.cluster.local:50051"
    "Replicas (HA)"            = var.weaviate_replicas
    "Storage Type"             = var.storage_type
    "Storage Size"             = var.storage_size
    "Vector Dimensions"        = var.vector_dimensions
    "Helm Release"             = var.helm_release_name
    "API Key Secret ARN"       = var.create_api_key ? aws_secretsmanager_secret.weaviate_api_key[0].arn : "Not Created"
    "Backup Bucket"            = var.enable_s3_backups ? aws_s3_bucket.weaviate_backups[0].id : "Backups Disabled"
    "IRSA Role ARN"            = aws_iam_role.weaviate_irsa.arn
    "EKS Cluster"              = local.cluster_name
    "Cluster Region"           = local.region
    "Admin Users"             = join(", ", var.weaviate_admin_users)
    "Read-Only Users"         = var.weaviate_readonly_users != [] ? join(", ", var.weaviate_readonly_users) : "None"
  }
}
