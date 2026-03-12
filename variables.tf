variable "platform_output" {
  description = "Platform output from airid188503_acc-aws-init-module (contains name, owner, environment_type)"
  type        = any
  validation {
    condition     = contains(keys(var.platform_output), "name")
    error_message = "platform_output must contain name key."
  }
}

variable "initialization_output" {
  description = "Initialization output from airid188503_acc-aws-init-module (contains VPC, subnets, KMS, SSH keys, region)"
  type        = any
  validation {
    condition     = contains(keys(var.initialization_output), "vpc_id") && contains(keys(var.initialization_output), "region")
    error_message = "initialization_output must contain vpc_id and region keys."
  }
}

variable "bastion_host_output" {
  description = "Bastion host output from airid188503_acc-aws-bastion-host-module (contains IPs, security group, role ARN)"
  type        = any
  default     = {}
}

variable "kubernetes_cluster_output" {
  description = "EKS cluster output from airid188503_acc-aws-eks-module (contains cluster_name, cluster_endpoint, OIDC info)"
  type        = any
  validation {
    condition     = contains(keys(var.kubernetes_cluster_output), "cluster_name") && contains(keys(var.kubernetes_cluster_output), "aws_iam_openid_connect_provider")
    error_message = "kubernetes_cluster_output must contain cluster_name and aws_iam_openid_connect_provider keys."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for Weaviate deployment"
  type        = string
  default     = "weaviate"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must be valid Kubernetes namespace name."
  }
}

variable "weaviate_replicas" {
  description = "Number of Weaviate replicas for HA"
  type        = number
  default     = 3
  validation {
    condition     = var.weaviate_replicas > 0 && var.weaviate_replicas <= 10
    error_message = "Replicas must be between 1 and 10."
  }
}

variable "vector_dimensions" {
  description = "Vector embedding dimensions (OpenAI: 1536, smaller models: 384, 1024)"
  type        = number
  default     = 1536
  validation {
    condition     = contains([128, 256, 384, 512, 768, 1024, 1536, 3072], var.vector_dimensions)
    error_message = "Vector dimensions must be 128, 256, 384, 512, 768, 1024, 1536, or 3072."
  }
}

variable "storage_size" {
  description = "PersistentVolume storage size for Weaviate data"
  type        = string
  default     = "50Gi"
  validation {
    condition     = can(regex("^[0-9]+Gi$", var.storage_size))
    error_message = "Storage size must be in Gi format (e.g., 50Gi)."
  }
}

variable "storage_type" {
  description = "Storage type: 'local' (hostPath - no CSI required), 'emptydir' (ephemeral), or 'persistent' (requires EBS CSI driver)"
  type        = string
  default     = "persistent"
  validation {
    condition     = contains(["local", "emptydir", "persistent"], var.storage_type)
    error_message = "storage_type must be 'local', 'emptydir', or 'persistent'."
  }
}

variable "storage_class" {
  description = "Kubernetes StorageClass for persistent storage (only used if storage_type='persistent')"
  type        = string
  default     = "gp3"
}

variable "weaviate_image" {
  description = "Weaviate Docker image and tag (should be explicit version, not 'latest')"
  type        = string
  default     = "semitechnologies/weaviate:1.25.1"
}

variable "helm_release_name" {
  description = "Helm release name for Weaviate"
  type        = string
  default     = "weaviate"
}

variable "helm_repository" {
  description = "Helm repository name (must be registered with 'helm repo add weaviate https://weaviate.github.io/weaviate-helm')"
  type        = string
  default     = "weaviate"
}

variable "helm_chart_version" {
  description = "Weaviate Helm chart version (required 17.0.0+ for Weaviate 1.25+)"
  type        = string
  default     = "17.7.0"
}

variable "create_api_key" {
  description = "Whether to create and store API key in Secrets Manager"
  type        = bool
  default     = true
}

variable "api_key_recovery_window" {
  description = "Days to wait before Secrets Manager fully deletes the API key (7-30 days)"
  type        = number
  default     = 7
  validation {
    condition     = var.api_key_recovery_window >= 7 && var.api_key_recovery_window <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "force_delete_secrets_on_destroy" {
  description = "Force delete secrets immediately on destroy (true=dev, false=prod with recovery window)"
  type        = bool
  default     = true
}

variable "enable_s3_backups" {
  description = "Enable daily S3 snapshots for Weaviate data backup"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of backup snapshots to retain"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days > 0 && var.backup_retention_days <= 90
    error_message = "Backup retention must be between 1 and 90 days."
  }
}

variable "helm_values_override" {
  description = "Additional Helm values to override defaults"
  type        = any
  default     = {}
}

variable "enable_authentication" {
  description = "Enable API key authentication (required for security in production)"
  type        = bool
  default     = true
}

variable "weaviate_admin_users" {
  description = "List of admin user emails for authorization"
  type        = list(string)
  default     = []
}

variable "weaviate_readonly_users" {
  description = "List of read-only user emails for authorization"
  type        = list(string)
  default     = []
}

variable "enable_grpc" {
  description = "Enable gRPC API access (enabled by default in Helm 17.0.0+)"
  type        = bool
  default     = true
}

variable "grpc_service_type" {
  description = "Kubernetes service type for gRPC ('LoadBalancer' for external access, 'ClusterIP' for internal)"
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "LoadBalancer", "NodePort"], var.grpc_service_type)
    error_message = "grpc_service_type must be 'ClusterIP', 'LoadBalancer', or 'NodePort'."
  }
}

variable "weaviate_run_as_user" {
  description = "User ID to run Weaviate container as (non-root for security, default 1000)"
  type        = number
  default     = 0
  validation {
    condition     = var.weaviate_run_as_user >= 1000 || var.weaviate_run_as_user == 0
    error_message = "weaviate_run_as_user must be 0 (root - not recommended) or >= 1000 (non-root)."
  }
}
