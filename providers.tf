provider "aws" {
  region = var.initialization_output.region
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_ca_cert)
  token                  = data.aws_eks_cluster_auth.weaviate.token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_ca_cert)
    token                  = data.aws_eks_cluster_auth.weaviate.token
  }
}

# Get Kubernetes auth token for the EKS cluster
data "aws_eks_cluster_auth" "weaviate" {
  name = local.cluster_name
}
