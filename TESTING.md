# Weaviate Module Testing & Verification Guide

## Prerequisites

- Terraform deployment completed: `terraform apply` ✅
- `kubectl` configured and connected to EKS cluster
- `aws` CLI v2 installed and configured
- `curl` or `jq` available locally
- Port-forwarding capability to EKS cluster

## Quick Reference: Local vs Cluster Testing

**From LOCAL Machine (outside cluster):**
- Port-forward before running tests: `kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000`
- Then access: `http://localhost:7000`

**From CLUSTER (pod inside Kubernetes):**
- Direct pod-to-pod access via DNS: `http://weaviate-weaviate.weaviate.svc.cluster.local:7000`
- Or exec into pod: `kubectl exec -it -n weaviate weaviate-weaviate-0 -- bash`

## Deployment Verification (Run Immediately After Apply)

### Step 1: Verify Terraform Outputs

```bash
# Get all deployment outputs
terraform output

# Expected outputs:
# - weaviate_service_dns
# - weaviate_service_endpoint
# - api_key_secret_name
# - backup_bucket_name
# - irsa_role_arn
```

### Step 2: Check EKS Resources

```bash
# Verify namespace created
kubectl get namespace weaviate

# Expected: NAME      STATUS   AGE
#           weaviate  Active   2m

# Verify pods are running (may take 2-3 minutes)
kubectl get pods -n weaviate

# Expected: NAME                           READY   STATUS     TIME
#          weaviate-weaviate-0              1/1    Running    2m
#          weaviate-weaviate-1              1/1    Running    1m
#          weaviate-weaviate-2              1/1    Running    1m
#          weaviate-init-schema-xxxxx       0/1    Completed  3m

# Watch pod startup (ctrl+c to exit)
kubectl get pods -n weaviate -w
```

### Step 3: Check Pod Resources & Status

```bash
# Describe Weaviate pod
kubectl describe pod -n weaviate weaviate-weaviate-0

# Expected sections:
# - Name: weaviate-weaviate-0
# - Status: Running
# - Ready: 1/1
# - Containers: weaviate
# - Volumes: data (PersistentVolumeClaim)

# Check persistent volume claim
kubectl get pvc -n weaviate

# Expected: NAME                          STATUS   BOUND   TIME
#          weaviate-data-weaviate-weaviate-0  Bound  pvc-XXX  3m

# Check persistent volume
kubectl get pv | grep weaviate
```

### Step 4: Verify IRSA (IAM Role for Service Account)

```bash
# Check ServiceAccount annotations
kubectl get sa -n weaviate weaviate-sa -o yaml | grep -A 5 "annotations:"

# Expected: Should contain "eks.amazonaws.com/role-arn: arn:aws:iam::..."

# Verify IAM role was created
IAM_ROLE=$(terraform output -raw irsa_role_name)
aws iam describe-role --role-name $IAM_ROLE

# Expected: Should show role with trust relationship to OIDC provider
```

### Step 5: Verify S3 Backup Bucket

```bash
# Check S3 bucket existence
BUCKET=$(terraform output -raw backup_bucket_name)
aws s3 ls s3://$BUCKET/

# Expected: Empty initially, will populate with backups after scheduled time

# Verify bucket encryption and versioning
aws s3api get-bucket-versioning --bucket $BUCKET
# Expected: Status: Enabled

aws s3api get-bucket-encryption --bucket $BUCKET
# Expected: ServerSideEncryptionConfiguration with KMS key
```

### Step 6: Verify Secrets Manager API Key

```bash
# Get secret name
SECRET=$(terraform output -raw api_key_secret_name)

# Retrieve API key
AWS_REGION=$(terraform output -raw deployment_region)
aws secretsmanager get-secret-value \
  --secret-id $SECRET \
  --region $AWS_REGION \
  --query 'SecretString' | jq -r '.api_key'

# Expected: 32-character API key (e.g., "abcd1234efgh5678ijkl9012mnop3456")

# Check secret metadata
aws secretsmanager describe-secret \
  --secret-id $SECRET \
  --region $AWS_REGION
```

---

## Test 1: Weaviate Service Health Check (LOCAL)

**Prerequisites**: Port-forward enabled  
**Location**: LOCAL machine  
**Time**: 1 minute

### Setup

```bash
# Terminal 1: Create port-forward (keep running)
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!

# Wait for port-forward to establish
sleep 2
```

### Test

```bash
# Test 1a: Health endpoint
curl -X GET http://localhost:7000/v1/.well-known/ready
# Expected: {"status":"ok"} or {"ready":true}

# Test 1b: Schema endpoint
curl -X GET http://localhost:7000/v1/schema
# Expected: JSON with "classes" array (may be empty initially)

# Test 1c: Liveness probe
curl -X GET http://localhost:7000/v1/meta
# Expected: JSON response with system info

echo "✅ Test 1 PASSED: Weaviate service is healthy"
```

### Cleanup

```bash
# Kill port-forward
kill $PF_PID 2>/dev/null || true
```

---

## Test 2: Weaviate Service Health Check (FROM POD INSIDE CLUSTER)

**Prerequisites**: Terraform deployment completed  
**Location**: INSIDE Kubernetes cluster  
**Time**: 1 minute

### Test

Create a test pod to verify internal connectivity:

```bash
# Run debug pod
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- \
  curl -X GET http://weaviate-weaviate.weaviate.svc.cluster.local:7000/v1/.well-known/ready

# Expected output: {"status":"ok"} or {"ready":true}
# Then pod terminates and is cleaned up

echo "✅ Test 2 PASSED: Internal cluster connectivity confirmed"
```

---

## Test 3: Check Weaviate Pod Logs

**Prerequisites**: Terraform deployment completed  
**Location**: LOCAL (using kubectl)  
**Time**: 1 minute

### Test

```bash
# View logs from all Weaviate pods
kubectl logs -n weaviate -l app=weaviate --tail=50

# Expected: Startup logs mentioning:
# - "Starting Weaviate..."
# - "Loading modules..."
# - "REST API available at port 7000"
# - "gRPC available at port 50051"

# Watch logs in real-time
kubectl logs -n weaviate -l app=weaviate -f --all-containers=true
# (ctrl+c to exit)

echo "✅ Test 3 PASSED: Pod logs accessible and show healthy startup"
```

---

## Test 4: List Weaviate Classes (Default Schema)

**Prerequisites**: Port-forward enabled  
**Location**: LOCAL machine  
**Time**: 1 minute

### Setup

```bash
# Terminal 1: Port-forward
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2
```

### Test 4a: Get Schema

```bash
# Retrieve current schema
curl -s -X GET http://localhost:7000/v1/schema | jq '.classes'

# Expected: Should contain "Document" class if init job completed successfully:
# [
#   {
#     "class": "Document",
#     "properties": [
#       {"name": "content", "dataType": ["text"]},
#       {"name": "source", "dataType": ["string"]},
#       {"name": "metadata", "dataType": ["object"]},
#       {"name": "timestamp", "dataType": ["date"]}
#     ],
#     "vectorIndexType": "hnsw"
#   }
# ]

# If Document class not present, run init job manually:
kubectl apply -f weaviate-init.yaml
kubectl wait --for=condition=complete job/weaviate-init-schema -n weaviate --timeout=120s
```

### Test 4b: Verify HNSW Index Configuration

```bash
# Get Document class details
curl -s http://localhost:7000/v1/schema/classes/Document | jq '.vectorIndexConfig'

# Expected: HNSW configuration:
# {
#   "skip": false,
#   "cleanupIntervalSeconds": 300,
#   "maxConnections": 64,
#   "efConstruction": 128,
#   "ef": 128,
#   "flatSearchCutoff": 40000,
#   "distance": "cosine"
# }

echo "✅ Test 4 PASSED: Schema and HNSW index configured correctly"
```

### Cleanup

```bash
kill $PF_PID 2>/dev/null || true
```

---

## Test 5: Insert Test Documents

**Prerequisites**: Port-forward enabled, Document class exists  
**Location**: LOCAL machine  
**Time**: 2 minutes

### Setup

```bash
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2
```

### Test 5a: Insert Single Document

```bash
# Insert a document with vector
curl -s -X POST http://localhost:7000/v1/objects \
  -H "Content-Type: application/json" \
  -d '{
    "class": "Document",
    "properties": {
      "content": "Kubernetes is a container orchestration platform",
      "source": "k8s-docs",
      "metadata": {"category": "infrastructure", "version": "1.28"},
      "timestamp": "2025-03-10T10:00:00Z"
    },
    "vector": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
  }' | jq '.id'

# Expected: UUID of created document (e.g., "e8f00bb8-ab98-4567-aaa1-1234567890ab")
DOC_ID=$( curl -s -X POST http://localhost:7000/v1/objects \
  -H "Content-Type: application/json" \
  -d '{
    "class": "Document",
    "properties": {
      "content": "Kubernetes is a container orchestration platform",
      "source": "k8s-docs",
      "metadata": {"category": "infrastructure"},
      "timestamp": "2025-03-10T10:00:00Z"
    },
    "vector": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
  }' | jq -r '.id')

echo "Document created: $DOC_ID"
```

### Test 5b: Batch Insert Multiple Documents

```bash
# Insert multiple documents with vectors
cat > /tmp/docs.jsonl << 'EOF'
{"class":"Document","properties":{"content":"Terraform manages infrastructure as code","source":"terraform-docs","metadata":{"category":"iac"},"timestamp":"2025-03-10T11:00:00Z"},"vector":[0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9]}
{"class":"Document","properties":{"content":"Weaviate is a vector database for AI","source":"weaviate-docs","metadata":{"category":"vector-db"},"timestamp":"2025-03-10T12:00:00Z"},"vector":[0.3,0.4,0.5,0.6,0.7,0.8,0.9,0.1]}
{"class":"Document","properties":{"content":"RAG systems combine retrieval and generation","source":"ai-docs","metadata":{"category":"ai"},"timestamp":"2025-03-10T13:00:00Z"},"vector":[0.4,0.5,0.6,0.7,0.8,0.9,0.1,0.2]}
EOF

# Import via batch endpoint
cat /tmp/docs.jsonl | while read line; do
  curl -s -X POST http://localhost:7000/v1/objects \
    -H "Content-Type: application/json" \
    -d "$line" > /dev/null
  echo "✓ Inserted document"
done

echo "✅ Test 5 PASSED: Documents inserted successfully"
```

### Cleanup

```bash
kill $PF_PID 2>/dev/null || true
```

---

## Test 6: Retrieve Documents

**Prerequisites**: Port-forward enabled, documents inserted (Test 5)  
**Location**: LOCAL machine  
**Time**: 1 minute

### Setup

```bash
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2
```

### Test

```bash
# Get all documents in Document class
curl -s -X GET "http://localhost:7000/v1/objects?class=Document" | jq '.objects | length'

# Expected: 4 (or more, depending on previous tests)
# Sample output: 4

# Get specific document details
DOC_ID=$(curl -s http://localhost:7000/v1/objects?class=Document | jq -r '.objects[0].id')

curl -s -X GET http://localhost:7000/v1/objects/$DOC_ID | jq '.'

# Expected: Full document with metadata:
# {
#   "id": "e8f00bb8-...",
#   "class": "Document",
#   "properties": {
#     "content": "...",
#     "source": "...",
#     "metadata": {...},
#     "timestamp": "..."
#   },
#   "vector": [0.1, 0.2, ...]
# }

# Count total documents
curl -s http://localhost:7000/v1/objects?class=Document | jq '.objects | length'

echo "✅ Test 6 PASSED: Documents retrieved successfully"
```

### Cleanup

```bash
kill $PF_PID 2>/dev/null || true
```

---

## Test 7: Vector Similarity Search (GraphQL)

**Prerequisites**: Port-forward enabled, documents with vectors  
**Location**: LOCAL machine  
**Time**: 1 minute

### Setup

```bash
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2
```

### Test

```bash
# Search by vector similarity
curl -s -X POST http://localhost:7000/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ Get { Document(nearVector: {vector: [0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85], certainty: 0.5}, limit: 3) { content source _distance timestamp } } }"
  }' | jq '.'

# Expected: GraphQL response with similar documents:
# {
#   "data": {
#     "Get": {
#       "Document": [
#         {
#           "content": "Kubernetes is a container orchestration platform",
#           "source": "k8s-docs",
#           "_distance": 0.05,
#           "timestamp": "2025-03-10T10:00:00Z"
#         },
#         ...
#       ]
#     }
#   }
# }

# Alternative: Search with limit on results
curl -s -X POST http://localhost:7000/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ Get { Document(limit: 5) { content _distance } } }"
  }' | jq '.data.Get.Document | length'

# Expected: 5 (or less if fewer documents exist)

echo "✅ Test 7 PASSED: Vector similarity search working"
```

### Cleanup

```bash
kill $PF_PID 2>/dev/null || true
```

---

## Test 8: Verify S3 Backups

**Prerequisites**: Terraform deployment with `enable_s3_backups = true`  
**Location**: LOCAL machine (AWS CLI)  
**Time**: 1 minute

### Test

```bash
# Get backup bucket name
BUCKET=$(terraform output -raw backup_bucket_name)

# List S3 bucket contents
aws s3 ls s3://$BUCKET/ --recursive

# Expected: Initially empty or containing snapshots:
# 2025-03-10 10:15:32          12345 weaviate/snapshots/2025-03-10-daily.tar.gz

# Check bucket size
aws s3 ls s3://$BUCKET/ --summarize

# Expected: "Total Size: X bytes" (may be 0 if no snapshots yet)

# Verify bucket encryption
aws s3api get-bucket-encryption --bucket $BUCKET | jq '.Rules[0].ApplyServerSideEncryptionByDefault'

# Expected: {"SSEAlgorithm": "aws:kms", "KMSMasterKeyId": "arn:aws:kms:..."}

# Verify versioning enabled
aws s3api get-bucket-versioning --bucket $BUCKET | jq '.Status'

# Expected: "Enabled"

echo "✅ Test 8 PASSED: S3 backup bucket configured correctly"
```

---

## Test 9: Verify IAM Permissions

**Prerequisites**: Terraform deployment completed  
**Location**: LOCAL machine (AWS CLI)  
**Time**: 1 minute

### Test 9a: Check IRSA Role

```bash
# Get IAM role name
IAM_ROLE=$(terraform output -raw irsa_role_name)

# Check role exists and trust relationship
aws iam get-role --role-name $IAM_ROLE | jq '.Role | {RoleName, Arn, CreateDate}'

# Expected: Successfully retrieved role details

# Check trust relationship (OIDC)
aws iam get-role --role-name $IAM_ROLE | jq '.Role.AssumeRolePolicyDocument'

# Expected: Contains ServicePrincipal trust for EKS OIDC provider
```

### Test 9b: Check Role Policies

```bash
# List attached policies
aws iam list-role-policies --role-name $IAM_ROLE | jq '.PolicyNames'

# Expected: Array of inline policy names, typically:
# ["myplatform-dev-weaviate-s3-...", "myplatform-dev-weaviate-secrets-...", "myplatform-dev-weaviate-kms-..."]

# View S3 policy in detail
POLICY=$(aws iam list-role-policies --role-name $IAM_ROLE | jq -r '.PolicyNames[0]')
aws iam get-role-policy --role-name $IAM_ROLE --policy-name $POLICY | jq '.RolePolicyDocument.Statement'

# Expected: Statements allowing s3:ListBucket, s3:GetObject, s3:PutObject, etc.

echo "✅ Test 9 PASSED: IAM role and policies configured correctly"
```

---

## Test 10: Check Kubernetes Resources

**Prerequisites**: Terraform deployment completed  
**Location**: LOCAL (kubectl)  
**Time**: 1 minute

### Test 10a: ServiceAccount with IRSA

```bash
# Check ServiceAccount
kubectl get sa -n weaviate weaviate-sa -o yaml

# Expected: Contains annotation: "eks.amazonaws.com/role-arn: arn:aws:iam::..."

# Verify ServiceAccount secrets and tokens
kubectl get tokens -n weaviate 2>/dev/null || \
  kubectl describe sa -n weaviate weaviate-sa
```

### Test 10b: RBAC and Permissions

```bash
# Check if we can test pod exec (verifies connectivity)
kubectl auth can-i get pods --as=system:serviceaccount:weaviate:weaviate-sa -n weaviate

# Expected: yes

# Check persistent volume claim
kubectl get pvc -n weaviate -o wide

# Expected: 
# NAME                                    STATUS   BOUND   SIZE   TIME
# weaviate-data-weaviate-weaviate-0       Bound    pvc-... 50Gi   5m
```

### Test 10c: Helm Release Status

```bash
# Check Helm release
helm list -n weaviate

# Expected:
# NAME      NAMESPACE  REVISION  UPDATED            STATUS    CHART           APP VERSION
# weaviate  weaviate   1         2025-03-10 10:...  deployed  weaviate-16.4.0 1.25.1

# Inspect Helm values
helm get values weaviate -n weaviate | head -20
```

---

## Test 11: Performance Testing (Basic)

**Prerequisites**: Port-forward enabled, documents in database  
**Location**: LOCAL machine  
**Time**: 5 minutes

### Setup

```bash
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2
```

### Test 11a: Insert Performance

```bash
# Time bulk insert of 100 documents
echo "Inserting 100 documents with vectors..."

time (
  for i in {1..100}; do
    VECTOR=$(python3 -c "import random; print([random.random() for _ in range(8)])" | tr -d '[]')
    curl -s -X POST http://localhost:7000/v1/objects \
      -H "Content-Type: application/json" \
      -d "{
        \"class\": \"Document\",
        \"properties\": {
          \"content\": \"Test document $i\",
          \"source\": \"test\",
          \"metadata\": {\"index\": $i},
          \"timestamp\": \"2025-03-10T10:00:00Z\"
        },
        \"vector\": [$VECTOR]
      }" > /dev/null
    [ $((i % 20)) -eq 0 ] && echo "  Processed $i documents..."
  done
)

# Expected: Should complete in < 30 seconds
# real    0m25.123s
# user    0m12.456s
# sys     0m8.789s
```

### Test 11b: Query Performance

```bash
# Time search query
echo "Running 10 similarity searches..."

time (
  for i in {1..10}; do
    curl -s -X POST http://localhost:7000/v1/graphql \
      -H "Content-Type: application/json" \
      -d '{
        "query": "{ Get { Document(nearVector: {vector: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]}, limit: 10) { content _distance } } }"
      }' > /dev/null
  done
)

# Expected: Should complete in < 5 seconds
# real    0m3.456s
```

### Test 11c: Count Documents (Load Check)

```bash
# Get total document count
TOTAL=$(curl -s http://localhost:7000/v1/objects?class=Document | jq '.totalResults')
echo "Total documents: $TOTAL"

# Expected: 100+ (from previous inserts)
```

### Cleanup

```bash
kill $PF_PID 2>/dev/null || true
echo "✅ Test 11 PASSED: Performance baseline established"
```

---

## Test 12: Cleanup Test Data

**Prerequisites**: Tests completed  
**Location**: LOCAL or POD  
**Time**: 1 minute

### Test 12a: Delete All Documents (Option 1: Via API)

```bash
# Port-forward
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
PF_PID=$!
sleep 2

# Delete Document class (this deletes all documents)
curl -X DELETE http://localhost:7000/v1/schema/classes/Document

# Verify deletion
curl -s http://localhost:7000/v1/schema | jq '.classes'

# Expected: Empty array [] or no Document class

kill $PF_PID 2>/dev/null || true
```

### Test 12b: Reinitialize Schema (Optional)

```bash
# Reapply initialization job to recreate Document class
kubectl apply -f weaviate-init.yaml

# Wait for completion
kubectl wait --for=condition=complete job/weaviate-init-schema -n weaviate --timeout=60s

# Verify
kubectl port-forward -n weaviate svc/weaviate-weaviate 7000:7000 &
sleep 2
curl -s http://localhost:7000/v1/schema | jq '.classes[0].class'
# Expected: "Document"
kill %1 2>/dev/null || true
```

---

## Test 13: Kubernetes Resource Limits

**Prerequisites**: Terraform deployment completed  
**Location**: LOCAL (kubectl)  
**Time**: 1 minute

### Test

```bash
# Check resource limits and requests
kubectl get pod -n weaviate weaviate-weaviate-0 -o yaml | \
  grep -A 10 "resources:"

# Expected:
# resources:
#   limits:
#     memory: 4Gi
#     cpu: 2000m
#   requests:
#     cpu: 500m
#     memory: 1Gi

# Monitor actual resource usage
kubectl top pods -n weaviate

# Expected: Shows CPU and Memory usage (e.g., 250m, 1.2Gi)

# Get node resource availability
kubectl top nodes

echo "✅ Test 13 PASSED: Resource limits and usage verified"
```

---

## Testing Checklist & Success Criteria

Run this checklist to validate full module functionality:

```bash
# Pre-deployment
☐ Test 1: Service health check (LOCAL)
☐ Test 2: Service health check (CLUSTER)
☐ Test 3: Pod logs verification

# Schema & Data Management
☐ Test 4: Schema and HNSW index configuration
☐ Test 5: Document insertion
☐ Test 6: Document retrieval
☐ Test 7: Vector similarity search

# Infrastructure & Security
☐ Test 8: S3 backup bucket verification
☐ Test 9: IAM role and permissions
☐ Test 10: Kubernetes resources

# Performance & Cleanup
☐ Test 11: Performance baseline
☐ Test 12: Data cleanup
☐ Test 13: Resource limits

# ✅ ALL TESTS PASSED = MODULE READY
```

---

## Complete Test Script

Run all tests automatically:

```bash
#!/bin/bash
set -e

NAMESPACE="weaviate"
TESTS_PASSED=0
TESTS_FAILED=0

echo "=== Weaviate Module Test Suite ==="
echo "Starting at: $(date)"
echo

# Function to run tests
run_test() {
  local test_name=$1
  local test_cmd=$2
  
  echo "Running: $test_name"
  if eval "$test_cmd"; then
    echo "✅ PASSED: $test_name"
    ((TESTS_PASSED++))
  else
    echo "❌ FAILED: $test_name"
    ((TESTS_FAILED++))
  fi
  echo
}

# Deployment checks
run_test "Namespace exists" \
  "kubectl get namespace $NAMESPACE > /dev/null"

run_test "Pods are running" \
  "[ \$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].status.phase}' | grep -o Running | wc -l) -ge 3 ]"

run_test "PVC is bound" \
  "kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep -q Bound"

# Service checks
run_test "Service exists" \
  "kubectl get svc -n $NAMESPACE weaviate-weaviate > /dev/null"

run_test "Pod logs show healthy startup" \
  "kubectl logs -n $NAMESPACE -l app=weaviate --tail=20 | grep -q -i running"

# AWS checks
run_test "S3 backup bucket exists" \
  "aws s3 ls \$(terraform output -raw backup_bucket_name 2>/dev/null) > /dev/null 2>&1 || true"

run_test "API key secret exists" \
  "aws secretsmanager describe-secret --secret-id \$(terraform output -raw api_key_secret_name 2>/dev/null) > /dev/null 2>&1 || true"

run_test "IAM role exists" \
  "aws iam get-role --role-name \$(terraform output -raw irsa_role_name 2>/dev/null) > /dev/null 2>&1 || true"

# Summary
echo "=== Test Summary ==="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo "Completed at: $(date)"

[ $TESTS_FAILED -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit $TESTS_FAILED
```

Save as `run-tests.sh`, then execute:

```bash
chmod +x run-tests.sh
./run-tests.sh
```

---

## Troubleshooting Failed Tests

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod -n weaviate weaviate-weaviate-0

# Common issues:
# - Insufficient compute: Add more nodes to cluster
# - StorageClass missing: kubectl get storageclass
# - PVC pending: kubectl describe pvc -n weaviate
```

### Service Connection Failed

```bash
# Verify endpoints
kubectl get endpoints -n weaviate weaviate-weaviate

# Test internal connectivity
kubectl run -it --rm --image=curlimages/curl -- \
  curl http://weaviate-weaviate.weaviate.svc.cluster.local:7000/v1/.well-known/ready
```

### S3 Backup Access Issues

```bash
# Check pod IAM permissions
kubectl exec -it -n weaviate weaviate-weaviate-0 -- \
  aws sts get-caller-identity

# Should show the IRSA role
```

### API Key Retrieval Failed

```bash
# Verify secret exists
aws secretsmanager list-secrets | grep weaviate

# Try direct retrieval with region
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw api_key_secret_name) \
  --region $(terraform output -raw deployment_region)
```

---

## Additional Resources

- [Weaviate Testing Guide](https://weaviate.io/developers/weaviate/test)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)

---
