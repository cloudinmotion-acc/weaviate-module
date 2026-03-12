# Weaviate on EKS - Terraform Module

Deploy Weaviate vector database on AWS EKS with Terraform.

## What This Does

- ✅ Deploys Weaviate on EKS via Helm
- ✅ 3 replicas for high availability  
- ✅ 50Gi persistent storage
- ✅ Daily S3 backups
- ✅ API key management (AWS Secrets Manager)
- ✅ IAM access for pod (IRSA)
- ✅ REST API + gRPC endpoints

## Requirements

- EKS cluster already created
- Terraform >= 1.0
- kubectl configured for EKS
- AWS CLI v2

## Quick Start

### 1. Initialize

```bash
cd /home/rhel/pgvector/weaviate
terraform init
```

### 2. Configure

Edit `terraform.tfvars` with your cluster details:

```hcl
platform_output = {
  name             = "testdb09"
  owner            = "your-email@company.com"
  environment_type = "dev"
}

initialization_output = {
  vpc_id          = "vpc-xxx"
  region          = "us-east-1"
  kms_key_arn     = "arn:aws:kms:..."
  private_subnets = ["subnet-xxx", "subnet-yyy", "subnet-zzz"]
}

bastion_host_output = {
  public_ip = "x.x.x.x"
}

kubernetes_cluster_output = {
  cluster_name                    = "testdb09-eks-dev"
  cluster_endpoint                = "https://xxx.eks.us-east-1.amazonaws.com"
  cluster_certificate_data        = "base64-cert"
  aws_iam_openid_connect_provider = "arn:aws:iam::xxx:oidc-provider/..."
  aws_iam_openid_url              = "oidc.eks.us-east-1.amazonaws.com/id/xxx"
}

# Optional - these are defaults
namespace             = "weaviate"
weaviate_replicas     = 3
vector_dimensions     = 1536
storage_size          = "50Gi"
storage_type          = "persistent"
enable_authentication = true
enable_grpc           = true
weaviate_admin_users  = ["your-email@company.com"]
```

### 3. Deploy

```bash
terraform plan
terraform apply
```

### 4. Verify

```bash
kubectl get pods -n weaviate
kubectl get svc -n weaviate
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `namespace` | `weaviate` | Kubernetes namespace |
| `weaviate_replicas` | `3` | Number of pods |
| `vector_dimensions` | `1536` | Embedding size |
| `storage_size` | `50Gi` | Volume size |
| `storage_type` | `persistent` | Storage mode |
| `enable_authentication` | `true` | Require API key |
| `enable_grpc` | `true` | Enable gRPC |
| `enable_s3_backups` | `true` | Daily backups |
| `weaviate_admin_users` | `[]` | Admin emails |

## Get API Key

```bash
SECRET_NAME=$(terraform output -raw api_key_secret_name)
aws secretsmanager get-secret-value \
  --secret-id=$SECRET_NAME \
  --region us-east-1 \
  --query 'SecretString' | jq -r '.api_key'
```

## Access Weaviate

### From Inside Cluster

```bash
kubectl port-forward -n weaviate svc/weaviate 7000:7000

# In another terminal:
curl -H "Authorization: Bearer YOUR_API_KEY" \
     http://localhost:7000/v1/objects
```

### From Outside (LoadBalancer)

```bash
kubectl get svc -n weaviate weaviate

# Use EXTERNAL-IP from output:
curl -H "Authorization: Bearer YOUR_API_KEY" \
     http://EXTERNAL-IP:7000/v1/objects
```

## Outputs

```bash
terraform output                              # All outputs
terraform output -raw service_endpoint        # REST API endpoint
terraform output -raw grpc_endpoint           # gRPC endpoint
terraform output -raw api_key_secret_name     # Secret name
```

## Common Tasks

### Scale Replicas

```bash
# Edit terraform.tfvars
weaviate_replicas = 5

terraform apply
```

### Increase Storage

```bash
# Edit terraform.tfvars
storage_size = "100Gi"

terraform apply
```

### View Logs

```bash
kubectl logs -n weaviate weaviate-0 --tail=50
```

### Destroy

```bash
terraform destroy
```

## Module Files

| File | Purpose |
|------|---------|
| `main.tf` | AWS & Kubernetes resources |
| `variables.tf` | Configuration options |
| `outputs.tf` | Output values |
| `locals.tf` | Helm configuration |
| `providers.tf` | Provider setup |
| `versions.tf` | Version requirements |
| `terraform.tfvars` | Your config |

## Known Issues

1. **Pod Readiness**: Shows 0/1 READY - authenticated readiness probes return 503. API works fine.
2. **EBS CSI**: Ensure EKS cluster has proper DNS/API connectivity.
3. **Storage**: Use `emptydir` for testing, `persistent` for production.

## Troubleshooting

### Pod Not Ready

```bash
kubectl describe pod -n weaviate weaviate-0
kubectl logs -n weaviate weaviate-0
```

### Storage Issues

```bash
kubectl get pvc -n weaviate
kubectl get pv
```

### API Not Responding

```bash
kubectl exec -it -n weaviate weaviate-0 -- \
  curl -H "Authorization: Bearer KEY" \
  http://localhost:7000/v1/objects
```

### Check Events

```bash
kubectl get events -n weaviate
```

---

**Weaviate**: 1.25.1  
**Helm Chart**: 17.7.0  
**Terraform**: >= 1.0
