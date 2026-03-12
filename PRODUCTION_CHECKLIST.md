# Weaviate Kubernetes Module - Production Checklist

Based on official [Weaviate Kubernetes Installation Guide](https://docs.weaviate.io/deploy/installation-guides/k8s-installation), this checklist ensures your module is production-ready.

## ✅ Pre-Deployment Steps

### 1. Add Weaviate Helm Repository
```bash
helm repo add weaviate https://weaviate.github.io/weaviate-helm
helm repo update
```

### 2. Verify Cluster Requirements
```bash
# Check Kubernetes version (must be >= 1.23)
kubectl version

# Check available StorageClasses (required for persistence)
kubectl get storageclasses

# Check cluster subnet IP ranges (must be in these ranges)
# 10.0.0.0/8, 100.64.0.0/10, 172.16.0.0/12, 192.168.0.0/16, 198.19.0.0/16
kubectl cluster-info
```

### 3. Verify Helm Version
```bash
helm version  # Must be v3 or higher
```

## ✅ Configuration Best Practices

### ✓ Version Pinning
- **Weaviate Image**: `1.25.1` (explicit version, not `latest`)
- **Helm Chart**: `17.7.0` (required for Weaviate 1.25+)

### ✓ Authentication & Authorization
- **API Key Authentication**: Enabled by default
- **Admin Users**: Set in `terraform.tfvars`
  ```hcl
  weaviate_admin_users = ["your.email@example.com"]
  ```
- **Read-only Users**: Optional
  ```hcl
  weaviate_readonly_users = ["readonly@example.com"]
  ```

### ✓ gRPC Configuration
- **gRPC Service**: Enabled by default
- **Service Type**: `LoadBalancer` (for external access)
  - Change to `ClusterIP` for internal-only access
  - Change to `NodePort` for node-based access

### ✓ Security Context
- **Run as Non-Root**: User ID `1000` (default)
- **Privilege Escalation**: Disabled
- **Read-only Root Filesystem**: Disabled (Weaviate needs write access)

### ✓ Resource Limits
```
requests:
  memory: 2Gi
  cpu: 1000m
limits:
  memory: 4Gi
  cpu: 2000m
```
- Adjust based on your replica count and workload
- Reference: Each replica needs 2-4GB memory for production

### ✓ Persistence Configuration
Supports three storage strategies:

1. **local** (Default - no CSI driver required)
   ```hcl
   storage_type = "local"
   # Uses hostPath with local-storage StorageClass
   # Note: Requires local-path provisioner setup
   ```

2. **persistent** (EBS CSI driver required)
   ```hcl
   storage_type = "persistent"
   storage_class = "gp3"
   # Standard production option
   ```

3. **emptydir** (Ephemeral - data lost on pod restart)
   ```hcl
   storage_type = "emptydir"
   # Dev/test only - NO DATA PERSISTENCE
   ```

### ✓ Replication & High Availability
```hcl
weaviate_replicas = 3  # Recommended for production
```
- Minimum 3 replicas for HA
- Each replica gets its own persistent volume (ReadWriteOnce)

### ✓ S3 Backups
- **Enabled**: By default
- **Retention**: 7 days
- **Provider**: AWS S3 with KMS encryption
- **Access**: Via IRSA (IAM Role for Service Accounts)

### ✓ Backup Storage
- Creates S3 bucket: `{platform_name}-dev-weaviate-backups-{account_id}`
- API key stored in AWS Secrets Manager
- Encrypted with KMS key from INFRASTRUCTURE module

## ✅ Deployment

### 1. Plan Terraform Changes
```bash
cd /home/rhel/pgvector/weaviate
terraform plan
```
Review output for:
- All 13+ resources are being created
- Correct namespace, replicas, storage size
- Correct gRPC and authentication settings

### 2. Apply Configuration
```bash
terraform apply -auto-approve
```

### 3. Verify Deployment
```bash
# Wait for pods to be Ready
kubectl get pods -n weaviate -w

# Check logs
kubectl logs -n weaviate -l app.kubernetes.io/name=weaviate

# Port forward to test REST API
kubectl port-forward -n weaviate svc/weaviate 7000:7000

# Port forward to test gRPC API
kubectl port-forward -n weaviate svc/weaviate 50051:50051

# In another terminal, test endpoint
curl -X GET http://localhost:7000/v1/meta
```

## ✅ Post-Deployment Verification

### 1. Verify Service Configuration
```bash
kubectl get svc -n weaviate
# Should show:
# - weaviate (LoadBalancer/ClusterIP)
# - weaviate-grpc (LoadBalancer/ClusterIP)

kubectl describe svc weaviate -n weaviate
kubectl describe svc weaviate-grpc -n weaviate
```

### 2. Verify Persistent Storage
```bash
kubectl get pvc -n weaviate
kubectl get pv
# Should show ReadWriteOnce, Bound, with correct size
```

### 3. Verify IRSA (IAM Role for Service Account)
```bash
kubectl get sa -n weaviate weaviate -o yaml
# Should show annotation: eks.amazonaws.com/role-arn: arn:aws:iam::...
```

### 4. Verify API Key
```bash
# Retrieved from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw api_key_secret_name) \
  --region us-east-1
```

### 5. Verify S3 Backup Bucket
```bash
aws s3 ls $(terraform output -raw backup_bucket_name)
# Should be empty initially
```

## ⚠️ Migration from Pre-1.25

If upgrading from Weaviate < 1.25:

1. **Delete existing StatefulSet**
   ```bash
   kubectl delete statefulset weaviate -n weaviate
   ```

2. **Update Helm chart version** to 17.0.0+
   ```hcl
   helm_chart_version = "17.7.0"
   ```

3. **Re-deploy**
   ```bash
   terraform apply
   ```

4. **Verify migration** (see post-deployment verification)

## 📊 Monitoring & Health Checks

### Health Endpoint
```bash
curl -X GET http://weaviate.weaviate.svc.cluster.local:7000/v1/meta
```

### Pod Status
```bash
kubectl describe pod -n weaviate weaviate-0
kubectl top pod -n weaviate
```

### Storage Usage
```bash
kubectl exec -it -n weaviate weaviate-0 -- df -h /var/lib/weaviate
```

## 🔒 Security Recommendations

1. **Enable Network Policies**
   ```bash
   # Restrict traffic to Weaviate pods
   kubectl apply -f - <<EOF
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: weaviate-netpol
     namespace: weaviate
   spec:
     podSelector:
       matchLabels:
         app.kubernetes.io/name: weaviate
     policyTypes:
       - Ingress
       - Egress
   EOF
   ```

2. **Use Private Endpoints for Services**
   - Set `grpc_service_type = "ClusterIP"` for internal services
   - Use VPN/bastion for external access

3. **Rotate API Keys Regularly**
   - Set `api_key_recovery_window` to enable scheduled rotation
   - Store keys in AWS Secrets Manager (handled by module)

4. **Enable Pod Security Policies**
   - Already configured: non-root user, no privilege escalation

5. **Use Private Container Registry** (optional)
   - Configure image pull secrets
   - Reference: https://docs.weaviate.io/deploy/configuration/authentication

## 📚 Troubleshooting

### Error: "No private IP address found"
**Solution**: Verify pod subnet is in valid IP range (10.0.0.0/8, 172.16.0.0/12, etc.)

### Error: "Cluster hostname may change"
**Solution**: Already handled - `CLUSTER_HOSTNAME=weaviate` is set in env variables

### Storage Issues
- For `local` storage: Requires local-path provisioner setup
- For `persistent`: Check EBS CSI driver is installed: `kubectl get ds -n kube-system`
- For `emptydir`: Data is ephemeral - don't use for production

### gRPC Connection Issues
- Verify gRPC service is `LoadBalancer` (get endpoint): `kubectl get svc -n weaviate weaviate-grpc`
- Test through port-forward first: `kubectl port-forward -n weaviate svc/weaviate-grpc 50051:50051`

### IRSA Not Working
```bash
# Verify IRSA annotation
kubectl get sa -n weaviate weaviate -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# Verify role trust policy
aws iam get-role --role-name <role-arn-from-above>
```

## 🚀 Performance Tuning

### Increase Replicas for Higher Throughput
```hcl
weaviate_replicas = 5
```

### Increase Storage Size
```hcl
storage_size = "100Gi"  # Adjust based on dataset size
```

### Adjust Resource Limits
```hcl
# In helm_values_override, increase requests/limits based on load
helm_values_override = {
  resources = {
    requests = {
      memory = "4Gi"
      cpu    = "2000m"
    }
    limits = {
      memory = "8Gi"
      cpu    = "4000m"
    }
  }
}
```

## 📖 Additional Resources

- [Weaviate Kubernetes Installation](https://docs.weaviate.io/deploy/installation-guides/k8s-installation)
- [Weaviate Authentication](https://docs.weaviate.io/deploy/configuration/authentication)
- [Weaviate Helm Chart GitHub](https://github.com/weaviate/weaviate-helm)
- [Kubernetes PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [EKS Storage Documentation](https://docs.aws.amazon.com/eks/latest/userguide/storage.html)
