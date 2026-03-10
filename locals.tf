locals {
  common_tags = merge(
    {
      Environment = var.environment
      Module      = "terraform-aws-weaviate-eks"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    },
    var.tags
  )

  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Kubernetes resources
  service_account_name = "weaviate-sa"
  
  # S3 backup bucket
  backup_bucket_name = "${local.name_prefix}-weaviate-backups-${data.aws_caller_identity.current.account_id}"
  
  # Secrets Manager
  api_key_secret_name = "${local.name_prefix}-weaviate-api-key"
  
  # Weaviate defaults
  default_helm_values = {
    replicaCount     = var.weaviate_replicas
    scheme           = "http"
    port             = 8080
    grpc_port        = 50051
    persistence      = {
      enabled    = true
      storageClassName = var.storage_class
      size       = var.storage_size
    }
    resources = {
      requests = {
        memory = "1Gi"
        cpu    = "500m"
      }
      limits = {
        memory = "4Gi"
        cpu    = "2000m"
      }
    }
    env = {
      DISK_USE_READONLY_PERCENTAGE = 80
      QUERY_DEFAULTS_LIMIT         = 25
      QUERY_MAXIMUM_RESULTS        = 10000
      BACKUP_PROVIDER              = "s3"
    }
  }
}

data "aws_caller_identity" "current" {}
