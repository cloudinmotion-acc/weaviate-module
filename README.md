# Weaviate EKS Terraform Module (terraform-aws-weaviate-eks)

## Overview

This Terraform module deploys **Weaviate** (an open-source vector database) on **AWS EKS (Elastic Kubernetes Service)** with production-ready features including:

- ✅ **Kubernetes-native deployment** via Helm chart
- ✅ **High availability** with 3 replicas (configurable)
- ✅ **Persistent storage** with 50Gi PersistentVolume (configurable)
- ✅ **Daily S3 backups** for disaster recovery
- ✅ **API key management** via AWS Secrets Manager  
- ✅ **IAM role & IRSA** for secure AWS access
- ✅ **Configurable vector dimensions** (1536 for OpenAI, 384-3072 range)
- ✅ **REST API** (gRPC optional, internal-only networking)
- ✅ **HNSW index** for fast similarity search on 1M+ vectors
- ✅ **Schema management** with automatic initialization

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **EKS Cluster** already created (module references existing cluster)
3. **Terraform** >= 1.0.1 installed
4. **kubectl** configured to access your EKS cluster
5. **AWS CLI** v2 installed (for API key retrieval)
6. **Helm** 3.0+ (module uses Helm provider)

### Required Environment Variables

```bash
# AWS credentials (one of these methods)
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
# OR
aws configure
# OR use IAM role on EC2/EKS

# Kubernetes context
export KUBECONFIG=~/.kube/config
# OR configure via aws eks update-kubeconfig --name <cluster> --region <region>
```

## Quick Start (5 minutes)

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Update Configuration

Edit `terraform.tfvars` with your EKS cluster details:


### 3. Validate & Deploy

```bash
# Validate configuration
terraform validate

# Review changes
terraform plan

# Deploy to EKS
terraform apply
```

### 4. Verify Deployment

```bash
# Check Weaviate pods
kubectl get pods -n weaviate

# Retrieve API Key
aws secretsmanager get-secret-value \
  --secret-id=$(terraform output -raw api_key_secret_name) \
  --query 'SecretString' | jq -r '.api_key'

# Run tests (see TESTING.md)
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              AWS Account (Region)                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│  EKS Cluster                                        │
│  ├── Namespace: weaviate                            │
│  ├── Weaviate Pods (3 replicas)                     │
│  │   ├── REST API (port 8080)                       │
│  │   ├── gRPC (port 50051)                          │
│  │   └── Mounted PersistentVolume (50Gi)            │
│  │                                                  │
│  └── ServiceAccount (IRSA role)                     │
│      ├── → IAM Role (pod → AWS auth)                │
│      ├── → S3 Bucket (daily backups)                │
│      ├── → Secrets Manager (API key)                │
│      └── → KMS (encryption)                         │
│                                                     │
└─────────────────────────────────────────────────────┘
         ↑
         │ kubectl/API
         │
┌────────┴─────────────────────────────────────────┐
│   Client Applications                             │
│  (in cluster or via port-forward)                 │
└────────────────────────────────────────────────────┘
```

## Module Inputs

### Required Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | - | **[REQUIRED]** EKS cluster name |
| `cluster_region` | string | `us-east-1` | AWS region of EKS cluster |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `namespace` | string | `weaviate` | Kubernetes namespace |
| `weaviate_replicas` | number | `3` | Number of Weaviate replicas (HA) |
| `vector_dimensions` | number | `1536` | Vector embedding dimensions |
| `storage_size` | string | `50Gi` | PersistentVolume size |
| `storage_class` | string | `gp3` | Kubernetes StorageClass |
| `create_api_key` | bool | `true` | Create Secrets Manager API key |
| `api_key_recovery_window` | number | `7` | Secret deletion recovery (7-30 days) |
| `enable_s3_backups` | bool | `true` | Enable daily S3 backups |
| `backup_retention_days` | number | `7` | Number of backup snapshots to retain |
| `environment` | string | `dev` | Environment name (dev/test/staging/prod) |
| `project_name` | string | `myplatform` | Project name for tagging |
| `weaviate_image` | string | `semitechnologies/weaviate:latest` | Docker image & tag |
| `helm_chart_version` | string | `16.4.0` | Weaviate Helm chart version |
| `helm_values_override` | map(any) | `{}` | Additional Helm values |
| `tags` | map(string) | `{}` | Additional AWS tags |

### Vector Dimensions Reference

- **1536** (default): OpenAI text-embedding-3-small / text-embedding-ada-002
- **3072**: OpenAI text-embedding-3-large
- **1024**: Cohere, mistral-embed
- **384**: Smaller models (lighter, faster, less storage)
- **768, 512, 256, 128**: Custom configurations

## Module Outputs

### Connection & Access

```hcl
weaviate_service_dns           # Internal Kubernetes DNS
weaviate_service_endpoint      # REST API endpoint (HTTP)
weaviate_grpc_endpoint         # gRPC endpoint

# Examples:
# http://weaviate-weaviate.weaviate.svc.cluster.local:8080
# weaviate-weaviate.weaviate.svc.cluster.local:50051
```

### API & Secrets

```hcl
api_key_secret_name            # Secrets Manager secret name
api_key_secret_arn             # ARN of API key secret
```

### Infrastructure

```hcl
backup_bucket_name             # S3 bucket for backups
backup_bucket_arn              # S3 bucket ARN
irsa_role_arn                  # IAM role for pod access
irsa_role_name                 # IAM role name
```

### Configuration

```hcl
vector_dimensions              # Configured embedding dimensions
namespace_name                 # Kubernetes namespace
helm_release_name              # Helm release name
deployment_region              # AWS deployment region
deployment_environment         # Environment (dev/test/staging/prod)
```

## Usage Examples

### Basic Deployment (Minimum Config)

```bash
# Set environment
export AWS_REGION=us-east-1
export EKS_CLUSTER=my-eks-cluster

# Deploy
cd ~/pgvector/weaviate
cat > terraform.tfvars << EOF
cluster_name   = "$EKS_CLUSTER"
cluster_region = "$AWS_REGION"
environment    = "dev"
EOF

terraform init
terraform validate
terraform apply
```

### Production Configuration

```hcl
# terraform.tfvars - Production settings

cluster_name            = "prod-eks-us-east-1"
cluster_region          = "us-east-1"
namespace               = "weaviate-prod"
weaviate_replicas       = 5                    # Higher HA
vector_dimensions       = 1536
storage_size            = "200Gi"              # Larger volume
storage_class           = "gp3"
create_api_key          = true
api_key_recovery_window = 30                   # Longer recovery
enable_s3_backups       = true
backup_retention_days   = 30                   # More backups
environment             = "prod"
project_name            = "myplatform"

helm_values_override = {
  replicaCount = 5
  resources = {
    requests = {
      memory = "2Gi"
      cpu    = "1000m"
    }
    limits = {
      memory = "8Gi"
      cpu    = "4000m"
    }
  }
}

tags = {
  Owner       = "platform-team"
  CostCenter  = "production"
  Application = "weaviate-vector-search"
  Backup      = "required"
}
```

## Vector Database & Schema

### Default Schema: Document Class

Weaviate is initialized with a default `Document` class for common use cases:

```json
{
  "class": "Document",
  "description": "A document with embedding and metadata",
  "vectorIndexType": "hnsw",
  "properties": [
    {
      "name": "content",
      "dataType": ["text"],
      "description": "Document text content"
    },
    {
      "name": "source",
      "dataType": ["string"],
      "description": "Document source (URL, filename, etc.)"
    },
    {
      "name": "metadata",
      "dataType": ["object"],
      "description": "JSON metadata (author, tags, etc.)"
    },
    {
      "name": "timestamp",
      "dataType": ["date"],
      "description": "Document creation/update time"
    }
  ]
}
```

### Creating Custom Classes

Add custom classes via Weaviate REST API:

```bash
# Port-forward to Weaviate
kubectl port-forward -n weaviate svc/weaviate-weaviate 8080:8080 &

# Create a new class
curl -X POST http://localhost:8080/v1/schema/classes \
  -H "Content-Type: application/json" \
  -d '{
    "class": "Product",
    "properties": [
      {"name": "name", "dataType": ["string"]},
      {"name": "description", "dataType": ["text"]},
      {"name": "price", "dataType": ["number"]}
    ]
  }'
```

## Connection Methods

### 1. From Within EKS Cluster (Pods)

```bash
# Direct connection (no port-forward needed)
curl -X GET http://weaviate-weaviate.weaviate.svc.cluster.local:8080/v1/.well-known/ready

# With API key (if enabled)
curl -X GET http://weaviate-weaviate.weaviate.svc.cluster.local:8080/v1/schema \
  -H "Authorization: Bearer $API_KEY"
```

### 2. From Local Machine (Port-Forward)

```bash
# Terminal 1: Create port-forward
kubectl port-forward -n weaviate svc/weaviate-weaviate 8080:8080

# Terminal 2: Test connection
curl -X GET http://localhost:8080/v1/.well-known/ready

# Python client
from weaviate import Client

client = Client("http://localhost:8080")
schema = client.schema.get()
print(schema)
```

### 3. Via LoadBalancer (Optional - Not Configured by Default)

To expose Weaviate externally, modify Helm values:

```hcl
helm_values_override = {
  service = {
    type = "LoadBalancer"  # Changes from ClusterIP
  }
}
```

Then retrieve the external IP:

```bash
kubectl get svc -n weaviate weaviate-weaviate -o wide
# Use the EXTERNAL-IP for external clients
```

## Data Ingestion Examples

### Python Example: Insert Documents with Embeddings

```python
import weaviate
from weaviate.util import generate_uuid5
import json

client = weaviate.Client("http://localhost:8080")

# Insert documents
documents = [
    {
        "content": "Terraform is an Infrastructure as Code tool",
        "source": "terraform-docs",
        "metadata": {"category": "infrastructure", "version": "1.0"}
    },
    {
        "content": "Kubernetes orchestrates containerized applications",
        "source": "k8s-docs",
        "metadata": {"category": "container-orchestration", "version": "1.25"}
    }
]

for doc in documents:
    doc_id = generate_uuid5(doc["content"])
    client.data_object.create(
        class_name="Document",
        data_object=doc,
        uuid=doc_id,
        vector=None  # Weaviate auto-generates vectors if model is configured
    )

print(f"Inserted {len(documents)} documents")
```

### Semantic Search Example

```python
import weaviate

client = weaviate.Client("http://localhost:8080")

# Search with text (requires vectorizer module in Weaviate)
# This is pseudocode - requires text2vec-transformers or similar configured
result = client.query \
    .get("Document", ["content", "source", "_distance"]) \
    .with_near_text({
        "concepts": ["container orchestration tool"]
    }) \
    .with_limit(5) \
    .do()

for item in result["data"]["Get"]["Document"]:
    print(f"Distance: {item['_distance']}")
    print(f"Content: {item['content']}")
```

### REST API Example: Insert & Search

```bash
# Insert document
curl -X POST http://localhost:8080/v1/objects \
  -H "Content-Type: application/json" \
  -d '{
    "class": "Document",
    "properties": {
      "content": "RAG systems combine retrieval with generation",
      "source": "ml-docs",
      "metadata": {"tags": ["ai", "retrieval"]},
      "timestamp": "2025-01-15T10:30:00Z"
    },
    "vector": [0.1, 0.2, 0.3, ...]
  }'

# List Documents
curl -X GET http://localhost:8080/v1/objects?class=Document

# Search by vector (semantic similarity)
curl -X POST http://localhost:8080/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ Get { Document(nearVector: {vector: [0.1, 0.2, 0.3, ...]}, limit: 5) { content source _distance } } }"
  }'
```

## RAG Implementation Example

RAG (Retrieval-Augmented Generation) combines Weaviate retrieval with LLM generation:

```python
import weaviate
from openai import OpenAI

# Initialize clients
weaviate_client = weaviate.Client("http://localhost:8080")
openai_client = OpenAI(api_key="sk-...")

def rag_query(user_query: str) -> str:
    """
    RAG workflow:
    1. Retrieve relevant documents from Weaviate
    2. Create augmented prompt
    3. Generate response using LLM
    """
    
    # 1. Retrieve from Weaviate (semantic search)
    retrieval_result = weaviate_client.query \
        .get("Document", ["content", "source"]) \
        .with_near_text({
            "concepts": [user_query],
            "certainty": 0.7
        }) \
        .with_limit(5) \
        .do()
    
    # Extract relevant documents
    documents = retrieval_result.get("data", {}).get("Get", {}).get("Document", [])
    context = "\n".join([d["content"] for d in documents])
    
    # 2. Create augmented prompt
    prompt = f"""Use the following context to answer the question.

Context:
{context}

Question: {user_query}

Answer:"""
    
    # 3. Generate response
    response = openai_client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7
    )
    
    return response.choices[0].message.content

# Example usage
answer = rag_query("How does Terraform manage infrastructure?")
print(answer)
```

## Backup & Recovery

### Daily S3 Backups (Automatic)

The module automatically creates daily snapshots to S3:

```bash
# View backups in S3
aws s3 ls s3://myplatform-dev-weaviate-backups-<account-id>/ --recursive

# Check backup sizes
aws s3 ls s3://myplatform-dev-weaviate-backups-<account-id>/ --summarize
```

### Manual Backup

```bash
# Create on-demand snapshot
kubectl exec -it -n weaviate weaviate-weaviate-0 -- \
  curl -X POST http://localhost:8080/v1/backups/s3

# Monitor backup
kubectl logs -n weaviate -l app=weaviate -f
```

### Recovery from Backup

```bash
# Restore from snapshot
kubectl exec -it -n weaviate weaviate-weaviate-0 -- \
  curl -X POST http://localhost:8080/v1/backups/s3/restore
```

## Security Best Practices

1. **Network Isolation**: Keep service as ClusterIP (internal only)
2. **API Keys**: Stored in Secrets Manager with auto-rotation capability
3. **IAM Roles**: Use IRSA for pod-to-AWS authentication
4. **Encryption**: S3 and Secrets Manager use KMS encryption
5. **Access Control**: Kubernetes RBAC restricts pod permissions
6. **Backups**: Daily S3 snapshots with versioning enabled
7. **Monitoring**: CloudWatch/Prometheus available via helm_values_override

## Monitoring & Observability

### Basic Kubernetes Monitoring

```bash
# Pod status
kubectl get pods -n weaviate
kubectl describe pod -n weaviate weaviate-weaviate-0

# Resource usage
kubectl top nodes
kubectl top pods -n weaviate

# Logs
kubectl logs -n weaviate -l app=weaviate
kubectl logs -n weaviate weaviate-weaviate-0 -f
```

### Weaviate Metrics Endpoint

```bash
# Metrics available at
kubectl port-forward -n weaviate svc/weaviate-weaviate 8080:8080
curl http://localhost:8080/metrics
```

### Integration with Prometheus (Optional)

Add Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'weaviate'
    static_configs:
      - targets: ['weaviate-weaviate.weaviate.svc.cluster.local:8080']
```

## Cost Optimization

| Strategy | Benefit | Trade-off |
|----------|---------|-----------|
| **Reduce Replicas** | Lower compute | Lower HA |
| **Smaller Storage** | Reduce EBS costs | Limited data capacity |
| **HNSW → Flat Index** | Faster ingestion | Slower queries |
| **Spot Instances** | 70% savings | Interruption risk |
| **Reserved Instances** | 40% savings | Long-term commitment |

### Cost Example (Medium Production)

```
EKS Cluster:       ~$600/month (shared)
Weaviate Nodes:    ~$200/month (3 medium instances)
EBS Storage:       ~$50/month (50Gi gp3)
S3 Backups:        ~$5/month (daily snapshots)
Data Transfer:     ~$10/month (typical)
─────────────────────────────
Total:             ~$865/month
```

## Troubleshooting

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod -n weaviate weaviate-weaviate-0
kubectl get events -n weaviate --sort-by='.lastTimestamp'

# Common causes:
# - Insufficient compute resources
# - StorageClass not found: kubectl get storageclass
# - PVC pending: kubectl get pvc -n weaviate
```

### API Connection Failure

```bash
# Test service DNS
kubectl run -it --rm debug --image=curlimages/curl -- \
  curl http://weaviate-weaviate.weaviate.svc.cluster.local:8080/v1/.well-known/ready

# Check service
kubectl get svc -n weaviate weaviate-weaviate -o wide

# Port-forward and test
kubectl port-forward -n weaviate svc/weaviate-weaviate 8080:8080
curl http://localhost:8080/v1/.well-known/ready
```

### S3 Backup Failures

```bash
# Check IAM permissions
aws iam get-role-policy --role-name $(terraform output -raw irsa_role_name) \
  --policy-name <policy-name>

# Check pod logs
kubectl logs -n weaviate weaviate-weaviate-0 | grep -i backup

# Verify S3 bucket
aws s3 ls $(terraform output -raw backup_bucket_name)
```

### API Key Issues

```bash
# Retrieve API key from Secrets Manager
SECRET_NAME=$(terraform output -raw api_key_secret_name)
aws secretsmanager get-secret-value --secret-id $SECRET_NAME \
  --query 'SecretString' | jq -r '.api_key'

# Rotate API key
aws secretsmanager rotate-secret --secret-id $SECRET_NAME
```

## File Structure

```
weaviate/
├── versions.tf                 # Provider versions & requirements
├── variables.tf                # Input variable definitions
├── locals.tf                   # Local computed values
├── data.tf                     # AWS data sources & IAM policies
├── main.tf                     # Kubernetes & Helm resources
├── outputs.tf                  # Output values for module users
├── providers.tf                # Provider configurations
├── terraform.tfvars            # Pre-populated configuration (EXCLUDED)
├── terraform.tfvars.example    # Template for other environments
├── .gitignore                  # Git ignore rules
├── weaviate-init.yaml          # Kubernetes schema initialization
├── README.md                   # This file
└── TESTING.md                  # Testing & verification procedures
```

## Testing & Verification

For comprehensive testing procedures, pod connection tests, API validation, and performance benchmarks, see [TESTING.md](TESTING.md).

Quick test:

```bash
# Deploy and verify
terraform apply
kubectl get pods -n weaviate

# Run basic health check
kubectl port-forward -n weaviate svc/weaviate-weaviate 8080:8080 &
curl -X GET http://localhost:8080/v1/.well-known/ready
```

## Clean Up & Destruction

### Remove Weaviate Deployment

```bash
# Delete test data first
kubectl exec -it -n weaviate weaviate-weaviate-0 -- \
  curl -X DELETE http://localhost:8080/v1/schema/Document

# Remove with Terraform (keeps S3 backups for 7 days)
terraform destroy

# Force immediate deletion of secrets
aws secretsmanager delete-secret \
  --secret-id $(terraform output -raw api_key_secret_name) \
  --force-delete-without-recovery
```

The destruction process:

1. **Local**: Terraform runs `helm uninstall` command
2. **Kubernetes**: Helm removes all Weaviate pods and PVCs
3. **S3**: Backups scheduled for deletion (recovery window: 7 days by default)
4. **Secrets Manager**: API key scheduled for deletion (not immediate)
5. **IAM**: Roles and policies removed immediately

**Important**: S3 backups and Secrets (if configured) use **scheduled deletion** for safety. Override with `--force-delete-without-recovery` if needed.

## Module Development & Customization

### Custom Weaviate Settings

Override Helm chart values:

```hcl
helm_values_override = {
  replicaCount = 5
  image.tag = "1.25.2"
  persistence.size = "100Gi"
  resources.limits.memory = "8Gi"
  env.DISK_USE_READONLY_PERCENTAGE = "75"
  env.QUERY_DEFAULTS_LIMIT = "100"
}
```

### Advanced: Custom StorageClass

Use specific StorageClass for higher IOPS:

```hcl
storage_class = "gp3-high-performance"

# First create the StorageClass in Kubernetes:
# kubectl apply -f -
# apiVersion: storage.k8s.io/v1
# kind: StorageClass
# metadata:
#   name: gp3-high-performance
# provisioner: ebs.csi.aws.com
# parameters:
#   iops: "16000"
#   throughput: "1000"
```

### Advanced: Persistent Scheduling

Customize pod affinity:

```hcl
helm_values_override = {
  affinity = {
    podAntiAffinity = {
      preferredDuringSchedulingIgnoredDuringExecution = [
        {
          weight = 100
          podAffinityTerm = {
            labelSelector = {
              matchExpressions = [
                {
                  key = "app"
                  operator = "In"
                  values = ["weaviate"]
                }
              ]
            }
            topologyKey = "kubernetes.io/hostname"
          }
        }
      ]
    }
  }
}
```

## Additional Resources

- [Weaviate Documentation](https://weaviate.io/developers/weaviate)
- [Weaviate Helm Chart](https://github.com/weaviate-k8s/weaviate-helm)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Storage](https://kubernetes.io/docs/concepts/storage/)
- [IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Support & Contributing

For issues, improvements, or questions:

1. Check [TESTING.md](TESTING.md) for common test scenarios
2. Review [AWS EKS documentation](https://docs.aws.amazon.com/eks/)
3. Check Weaviate GitHub issues: https://github.com/weaviate/weaviate/issues
4.  Review logs: `kubectl logs -n weaviate -l app=weaviate`

---

**Module Version**: 1.0.0  
**Last Updated**: March 2025  
**Maintenance**: terraform-aws-weaviate-eks
