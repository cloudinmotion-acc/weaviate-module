# Weaviate on EKS

Deploy Weaviate vector database on AWS EKS with Terraform.

## What This Does

- ✅ Deploys Weaviate on EKS via Helm
- ✅ 3(default) replicas for high availability  
- ✅ 50Gi(default) persistent storage
- ✅ Daily S3 backups
- ✅ API key management (AWS Secrets Manager)
- ✅ IAM access for pod (IRSA)
- ✅ REST API + gRPC endpoints


## Quick Start

### 1. Initialize

```bash
terraform init
```

### 2. Configure

Edit `terraform.tfvars`:

```hcl
platform_output = {
  name             = "testdb09"
  owner            = "your-email@company.com"
  environment_type = "dev"
  ....
}

initialization_output = {
  vpc_id          = "vpc-xxx"
  region          = "us-east-1"
  kms_key_arn     = "arn:aws:kms:..."
  private_subnets = ["subnet-xxx", "subnet-yyy", "subnet-zzz"]
  ......
}

bastion_host_output = {
  public_ip = "x.x.x.x"
  ......
}

kubernetes_cluster_output = {
  cluster_name                    = "testdb09-eks-dev"
  cluster_endpoint                = "https://xxx.eks.us-east-1.amazonaws.com"
  cluster_certificate_data        = "base64-cert"
  aws_iam_openid_connect_provider = "arn:aws:iam::xxx:oidc-provider/..."
  aws_iam_openid_url              = "oidc.eks.us-east-1.amazonaws.com/id/xxx"
  
}

# Optional Weaviate settings (these are defaults)

weaviate_replicas     = 3
vector_dimensions     = 1536
storage_size          = "50Gi"
weaviate_admin_users  = ["your-email@company.com"]
weaviate_readonly_users = []
grpc_service_type       = "ClusterIP" # Use ClusterIP for internal access, LoadBalancer for external
```

### 3. Deploy

```bash
terraform plan    # Preview changes
terraform apply   # Deploy
```

### 4. Verify

```bash
kubectl get pods -n weaviate
kubectl get svc -n weaviate  # See endpoints
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `namespace` | `weaviate` | Kubernetes namespace |
| `weaviate_replicas` | `3` | Number of pods |
| `vector_dimensions` | `1536` | Embedding size (OpenAI compatible) |
| `storage_size` | `50Gi` | PersistentVolume size |
| `storage_type` | `persistent` | Storage mode |
| `enable_authentication` | `true` | Require API key |
| `enable_grpc` | `true` | Enable gRPC |
| `enable_s3_backups` | `true` | Daily backups |
| `weaviate_admin_users` | `[]` | Admin email list |

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
# Pod to pod (port-forward)
kubectl port-forward -n weaviate svc/weaviate 8080:80

# Then from another terminal
curl -H "Authorization: Bearer YOUR_API_KEY" \
     http://localhost:8080/v1/objects
```

### From Outside (LoadBalancer)

```bash
# Get LoadBalancer address
kubectl get svc -n weaviate weaviate

# Use the EXTERNAL-IP
curl -H "Authorization: Bearer YOUR_API_KEY" \
     http://EXTERNAL-IP:80/v1/objects
```

## Outputs

```bash
# All outputs
terraform output

# Specific outputs
terraform output -raw service_endpoint
terraform output -raw grpc_endpoint
terraform output -raw api_key_secret_name
```

## Common Tasks

### Scale Replicas

```bash
# Edit terraform.tfvars
weaviate_replicas = 5

# Apply
terraform apply
```

### Increase Storage

```bash
# Edit terraform.tfvars
storage_size = "100Gi"

# Apply
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

## Support

Check logs:
```bash
kubectl logs -n weaviate weaviate-0
```

Check events:
```bash
kubectl get events -n weaviate
```

Check PVC:
```bash
kubectl get pvc -n weaviate
```
