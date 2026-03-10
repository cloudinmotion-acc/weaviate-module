# EKS Cluster data source
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# Current AWS account
data "aws_caller_identity" "current" {}

# Current AWS region
data "aws_region" "current" {}

# KMS key for Secrets Manager encryption
data "aws_kms_alias" "secrets" {
  name = "alias/aws/secretsmanager"
}

# IAM policy document for S3 backups
data "aws_iam_policy_document" "weaviate_s3_backups" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${local.backup_bucket_name}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucketVersions"
    ]
    resources = [
      "arn:aws:s3:::${local.backup_bucket_name}/*"
    ]
  }
}

# IAM policy document for Secrets Manager access
data "aws_iam_policy_document" "weaviate_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.cluster_region}:${data.aws_caller_identity.current.account_id}:secret:${local.api_key_secret_name}-*"
    ]
  }
}

# IAM policy document for KMS decryption
data "aws_iam_policy_document" "weaviate_kms" {
  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey"
    ]
    resources = [
      data.aws_kms_alias.secrets.target_key_arn
    ]
  }
}
