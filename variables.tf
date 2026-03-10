variable "cluster_name" {
  description = "EKS cluster name to deploy Weaviate to"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name must not be empty."
  }
}

variable "cluster_region" {
  description = "AWS region where EKS cluster is located"
  type        = string
  default     = "us-east-1"
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

variable "storage_class" {
  description = "Kubernetes StorageClass for Weaviate PersistentVolume"
  type        = string
  default     = "gp3"
}

variable "weaviate_image" {
  description = "Weaviate Docker image and tag"
  type        = string
  default     = "semitechnologies/weaviate:latest"
}

variable "helm_release_name" {
  description = "Helm release name for Weaviate"
  type        = string
  default     = "weaviate"
}

variable "helm_repository" {
  description = "Helm repository URL for Weaviate chart"
  type        = string
  default     = "https://weaviate-k8s.github.io/weaviate-helm"
}

variable "helm_chart_version" {
  description = "Weaviate Helm chart version"
  type        = string
  default     = "16.4.0"
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

variable "environment" {
  description = "Environment name (dev, test, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, test, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for tagging and resource naming"
  type        = string
  default     = "myplatform"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "helm_values_override" {
  description = "Additional Helm values to override defaults"
  type        = any
  default     = {}
}
