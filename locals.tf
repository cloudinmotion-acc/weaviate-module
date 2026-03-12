locals {
  common_tags = merge(
    {
      Environment = var.platform_output.environment_type
      Owner       = var.platform_output.owner
      Component   = "weaviate"
      Module      = "terraform-aws-weaviate-eks"
      Project     = var.platform_output.name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  )

  # Kubernetes-safe labels (must be alphanumeric, hyphens, underscores, dots only)
  # Sanitized version of common_tags for Kubernetes resources
  kubernetes_labels = {
    Environment = var.platform_output.environment_type
    Component   = "weaviate"
    Module      = "terraform-aws-weaviate-eks"
    Project     = var.platform_output.name
    ManagedBy   = "Terraform"
  }

  # Extract outputs from dependent modules
  platform_name       = var.platform_output.name
  region              = var.initialization_output.region
  vpc_id              = var.initialization_output.vpc_id
  private_subnets    = var.initialization_output.private_subnets
  kms_key_arn         = var.initialization_output.kms_key_arn

  # EKS cluster details from module output
  cluster_name     = var.kubernetes_cluster_output.cluster_name
  cluster_id       = var.kubernetes_cluster_output.cluster_id
  cluster_arn      = var.kubernetes_cluster_output.cluster_arn
  cluster_endpoint = var.kubernetes_cluster_output.cluster_endpoint
  cluster_ca_cert  = var.kubernetes_cluster_output.cluster_certificate_data
  oidc_provider_arn = var.kubernetes_cluster_output.aws_iam_openid_connect_provider
  oidc_provider_url = var.kubernetes_cluster_output.aws_iam_openid_url

  # Resource naming - use platform name instead of project_name
  name_prefix = "${local.platform_name}-${var.platform_output.environment_type}"
  
  # Kubernetes resources
  service_account_name = "weaviate-sa"
  
  # S3 backup bucket
  backup_bucket_name = "${local.name_prefix}-weaviate-backups-${data.aws_caller_identity.current.account_id}"
  
  # Secrets Manager
  api_key_secret_name = "${local.name_prefix}-weaviate-api-key"
  
  # Weaviate defaults
  # Determine persistence config based on storage_type (alternative to EBS CSI)
  persistence_config = var.storage_type == "persistent" ? {
    enabled              = true
    storageClassName     = var.storage_class
    size                 = var.storage_size
  } : var.storage_type == "local" ? {
    enabled              = true
    storageClassName     = "local-storage"
    size                 = var.storage_size
  } : {
    enabled              = false
  }

  default_helm_values = {
    replicaCount     = var.weaviate_replicas
    scheme           = "http"
    port             = 7000
    grpc_port        = 50051
    persistence      = local.persistence_config
    
    # Security context - note: init container runs as root to configure node
    # Main container runs as specified user (default root for Weaviate)
    containerSecurityContext = {
      runAsUser       = var.weaviate_run_as_user
      runAsNonRoot    = var.weaviate_run_as_user != 0
      allowPrivilegeEscalation = false
      readOnlyRootFilesystem  = false
    }
    
    # Resource limits (per official docs)
    resources = {
      requests = {
        memory = "2Gi"
        cpu    = "1000m"
      }
      limits = {
        memory = "4Gi"
        cpu    = "2000m"
      }
    }
    
    # gRPC service configuration (enabled by default in 17.0.0+)
    grpcService = {
      enabled = var.enable_grpc
      type    = var.grpc_service_type
    }
    
    # Authentication - API key enabled with users configuration
    authentication = var.enable_authentication ? {
      apikey = {
        enabled = true
        allowed_keys = var.create_api_key ? [random_password.weaviate_api_key[0].result] : []
        users = concat(
          var.weaviate_admin_users,
          var.weaviate_readonly_users
        )
      }
      anonymous_access = {
        enabled = false
      }
    } : {
      apikey = {
        enabled = false
        allowed_keys = []
        users = []
      }
      anonymous_access = {
        enabled = true
      }
    }
    
    # Authorization - admin and readonly user mapping
    authorization = var.enable_authentication && length(concat(var.weaviate_admin_users, var.weaviate_readonly_users)) > 0 ? {
      admin_list = {
        enabled = length(var.weaviate_admin_users) > 0
        users   = var.weaviate_admin_users
      }
    } : {}
    
    # Environment variables
    env = {
      CLUSTER_HOSTNAME             = "weaviate"
      DISK_USE_READONLY_PERCENTAGE = 80
      QUERY_DEFAULTS_LIMIT         = 25
      QUERY_MAXIMUM_RESULTS        = 10000
      BACKUP_PROVIDER              = "s3"
      # Telemetry - set to false if you want to opt-out
      DISABLE_TELEMETRY            = false
    }
  }
}
