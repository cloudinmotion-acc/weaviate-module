# Create Kubernetes namespace
resource "kubernetes_namespace" "weaviate" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "weaviate"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create ServiceAccount for Weaviate
resource "kubernetes_service_account" "weaviate" {
  metadata {
    name      = local.service_account_name
    namespace = kubernetes_namespace.weaviate.metadata[0].name
    labels = merge(
      local.common_tags,
      {
        "app.kubernetes.io/component" = "weaviate"
      }
    )
  }

  depends_on = [kubernetes_namespace.weaviate]
}

# Create IAM role for Weaviate (IRSA)
resource "aws_iam_role" "weaviate_irsa" {
  name_prefix = "${local.name_prefix}-weaviate-irsa-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${kubernetes_namespace.weaviate.metadata[0].name}:${local.service_account_name}"
            "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach S3 backup policy
resource "aws_iam_role_policy" "weaviate_s3_backups" {
  name_prefix = "${local.name_prefix}-weaviate-s3-"
  role        = aws_iam_role.weaviate_irsa.id
  policy      = data.aws_iam_policy_document.weaviate_s3_backups.json
}

# Attach Secrets Manager policy
resource "aws_iam_role_policy" "weaviate_secrets" {
  name_prefix = "${local.name_prefix}-weaviate-secrets-"
  role        = aws_iam_role.weaviate_irsa.id
  policy      = data.aws_iam_policy_document.weaviate_secrets.json
}

# Attach KMS policy
resource "aws_iam_role_policy" "weaviate_kms" {
  name_prefix = "${local.name_prefix}-weaviate-kms-"
  role        = aws_iam_role.weaviate_irsa.id
  policy      = data.aws_iam_policy_document.weaviate_kms.json
}

# Annotate ServiceAccount with IAM role
resource "kubernetes_service_account_v1_patch" "weaviate_irsa" {
  metadata {
    name      = kubernetes_service_account.weaviate.metadata[0].name
    namespace = kubernetes_service_account.weaviate.metadata[0].namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.weaviate_irsa.arn
    }
  }

  depends_on = [kubernetes_service_account.weaviate]
}

# S3 bucket for backups
resource "aws_s3_bucket" "weaviate_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = local.backup_bucket_name

  tags = local.common_tags
}

# Enable versioning for backup retention
resource "aws_s3_bucket_versioning" "weaviate_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.weaviate_backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "weaviate_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.weaviate_backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.aws_kms_alias.secrets.target_key_arn
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "weaviate_backups" {
  count  = var.enable_s3_backups ? 1 : 0
  bucket = aws_s3_bucket.weaviate_backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Secrets Manager secret for API key
resource "random_password" "weaviate_api_key" {
  count       = var.create_api_key ? 1 : 0
  length      = 32
  special     = true
  prefer_special_chars = false
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "weaviate_api_key" {
  count                   = var.create_api_key ? 1 : 0
  name_prefix             = "${local.api_key_secret_name}-"
  recovery_window_in_days = var.api_key_recovery_window
  kms_key_id              = data.aws_kms_alias.secrets.target_key_arn

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "weaviate_api_key" {
  count         = var.create_api_key ? 1 : 0
  secret_id     = aws_secretsmanager_secret.weaviate_api_key[0].id
  secret_string = jsonencode({
    api_key = random_password.weaviate_api_key[0].result
  })
}

# Helm release for Weaviate
resource "helm_release" "weaviate" {
  name             = var.helm_release_name
  repository       = var.helm_repository
  chart            = "weaviate"
  version          = var.helm_chart_version
  namespace        = kubernetes_namespace.weaviate.metadata[0].name
  create_namespace = false

  values = [
    yamlencode(merge(
      local.default_helm_values,
      {
        serviceAccount = {
          name   = kubernetes_service_account.weaviate.metadata[0].name
          create = false
        }
        image = {
          repository = split(":", var.weaviate_image)[0]
          tag        = split(":", var.weaviate_image)[1]
          pullPolicy = "IfNotPresent"
        }
      },
      var.helm_values_override
    ))
  ]

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = var.storage_class
  }

  set {
    name  = "persistence.size"
    value = var.storage_size
  }

  depends_on = [
    kubernetes_service_account_v1_patch.weaviate_irsa,
    aws_iam_role_policy.weaviate_s3_backups,
    aws_iam_role_policy.weaviate_secrets,
    aws_iam_role_policy.weaviate_kms
  ]

  wait = true

  lifecycle {
    ignore_changes = [values]
  }
}

# Destroy provisioner to clean up on destroy
resource "null_resource" "helm_cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "helm uninstall ${var.helm_release_name} -n ${var.namespace} --ignore-not-found 2>/dev/null || true"
    on_failure = continue
  }

  depends_on = [helm_release.weaviate]
}
