# Mandatory output blocks for MyPlatform module reporting
output "mpp_report" {
  description = "MyPlatform report block"
  value = {
    module_name    = "terraform-aws-weaviate-eks"
    module_source  = "~/pgvector/weaviate"
    module_version = "1.0.0"
    provisioner    = "terraform"
    status         = "deployed"
    created_by     = "terraform"
  }
}

output "pgvector_output" {
  description = "Weaviate module outputs for platform integration"
  value = {
    cluster_name    = var.cluster_name
    namespace       = kubernetes_namespace.weaviate.metadata[0].name
    service_name    = "${var.helm_release_name}-weaviate"
    replicas        = var.weaviate_replicas
    storage_size    = var.storage_size
  }
}

# Connection and access information
output "weaviate_service_dns" {
  description = "Internal Kubernetes service DNS name for Weaviate"
  value       = "${var.helm_release_name}-weaviate.${kubernetes_namespace.weaviate.metadata[0].name}.svc.cluster.local"
}

output "weaviate_service_endpoint" {
  description = "Weaviate REST API endpoint (internal)"
  value       = "http://${var.helm_release_name}-weaviate.${kubernetes_namespace.weaviate.metadata[0].name}.svc.cluster.local:8080"
}

output "weaviate_grpc_endpoint" {
  description = "Weaviate gRPC endpoint (internal)"
  value       = "${var.helm_release_name}-weaviate.${kubernetes_namespace.weaviate.metadata[0].name}.svc.cluster.local:50051"
}

# API key information
output "api_key_secret_name" {
  description = "AWS Secrets Manager secret name containing Weaviate API key"
  value       = var.create_api_key ? aws_secretsmanager_secret.weaviate_api_key[0].name : null
  sensitive   = true
}

output "api_key_secret_arn" {
  description = "ARN of the API key secret in Secrets Manager"
  value       = var.create_api_key ? aws_secretsmanager_secret.weaviate_api_key[0].arn : null
  sensitive   = true
}

# S3 backup information
output "backup_bucket_name" {
  description = "S3 bucket name for Weaviate backups"
  value       = var.enable_s3_backups ? aws_s3_bucket.weaviate_backups[0].id : null
}

output "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  value       = var.enable_s3_backups ? aws_s3_bucket.weaviate_backups[0].arn : null
}

# IAM role information
output "irsa_role_arn" {
  description = "ARN of the IAM role for IRSA (pod -> AWS)"
  value       = aws_iam_role.weaviate_irsa.arn
}

output "irsa_role_name" {
  description = "Name of the IAM role for IRSA"
  value       = aws_iam_role.weaviate_irsa.name
}

# Vector configuration
output "vector_dimensions" {
  description = "Configured vector embedding dimensions"
  value       = var.vector_dimensions
}

# Debugging and monitoring
output "namespace_name" {
  description = "Kubernetes namespace where Weaviate is deployed"
  value       = kubernetes_namespace.weaviate.metadata[0].name
}

output "helm_release_name" {
  description = "Helm release name for Weaviate"
  value       = var.helm_release_name
}

output "deployment_region" {
  description = "AWS region of deployment"
  value       = var.cluster_region
}

output "deployment_environment" {
  description = "Environment (dev, test, staging, prod)"
  value       = var.environment
}
