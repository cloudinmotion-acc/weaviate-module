platform_output = {
  name               = "testdb09"
  owner              = "akshaya.durgapu@accenture.com"
  environment_type   = "dev"
  system_name        = "testdb09"
  tags = {
    key = "value"
  }
}

initialization_output = {
  vpc_id               = "vpc-0fd0f6ad9c5ed4d0f"
  region               = "us-east-1"
  kms_key_arn          = "arn:aws:kms:us-east-1:310378384655:key/a19ce40a-b451-42ac-89b3-cbaf1c2b1f26"
  private_subnets     = ["subnet-0704706ad537d786b", "subnet-0b4cac5197151ec5c", "subnet-04ae203c03da9e117"]
  public_subnets      = ["subnet-014e5686f9491f793", "subnet-0693d3732656c8b44", "subnet-02b83b5de273788e9"]
  ssh_key_name        = "testdb09-dev"
  db_subnet_group     = "testdb09-dev"
  dns_private_zone_id = "ZZFUBY9TCMW6"
  dns_public_zone_id  = "Z1TW5XLJTWEHGA"
}

bastion_host_output = {
  bastion_host_user    = "rhel"
  private_ip           = "172.16.22.226"
  public_ip            = "34.205.21.154"
  public_dns           = "ec2-34-205-21-154.compute-1.amazonaws.com"
  security_group_id    = "sg-0963392ab469e820b"
  role_arn             = "arn:aws:iam::310378384655:role/testdb09-bastion-host-dev"
  role_name            = "testdb09-bastion-host-dev"
}

kubernetes_cluster_output = {
  cluster_name                    = "testdb09-eks-dev"
  cluster_id                      = "testdb09-eks-dev"
  cluster_arn                     = "arn:aws:eks:us-east-1:310378384655:cluster/testdb09-eks-dev"
  cluster_endpoint                = "https://DECAA7B26578A89860C3ED8F1C5F6C59.gr7.us-east-1.eks.amazonaws.com"
  cluster_certificate_data        = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJTG56M2cwbjYxZUF3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TmpBek1UQXdOakkyTlROYUZ3MHpOakF6TURjd05qTXhOVE5hTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUN2MnB3VWRxeGVYa2YvRnRsUjdlMG9COThySjZOUWkwYmhSYlVoZHRiVmlENGRFQzNrSExmY1ppYmMKMlp0bnNISWhCcUwrcVVVaStzSUd1MzRkSmNxb1c1ODRRek1nYkNVZmN2R2ZMQlR0V2MxUWR4YnZjK3ljSWJudAoydnJpNWxubEhRY2RtMmZWcWZ2aXd5VVNwZWFONi9JVFY5eGt1Wi9DbTJYYXFDaTlGb2FscWR1VUYvTlFzVmoyClYwZjRtSzZkaXRuU2kvZGxMK2hWRkg1NUFnRWM0REVoaG5Ub0ZHY2R4M1lscmFtQUZEOUl0eWJCMk9RLzdNWUUKcy9tUnJ2NEJ1dFdRRnloakJ1SC96UnRSSkM3QUM0QzhnZldVVTBvd3Y3VDJlQUZSSDVtZldYY2lFekx3NWd2MQpmZG50N1BUUkQxRElabDhjbHJIbURVdG02ekJKQWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTaWtmU3RKSFlYQmhKdGdLbTdpbFUxYUhmVjF6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQVMyVm1veWZBWApGVjFSbUdJZUtqMHNOTEIxYXJpakdOUk1oRTJWWGZBYk5aTU5JU25nSStMeXZCWXhuMlJEaXUzN0dvTTM1alJSClhJQXJkaCtRR1Z1aGZiQUtOZEJJSW5oWURLYXphd0FKdkhLSW1kVElzbkVjUFhxL0drUTN2b3R0aFNNSHVqazkKdllRWWN0RkRVUEN2ZElBTmxuazIzSnFLeWRuY0p3WTZmMVJzdDlweDQxalJHWXE5ME82ZXRRemhyTXpjVHllNQpSa1piaHBPSXMxeTNDNmRTa1RIY3EyTmlzTGNVNXdBbTI1UUtRWjFTNDJmaTdGb3F6ckJ3NHN0VXZVZjdzUlY4CnZLd081elZrd09teExIVlFpMEg3MitHckVQejF1dnpTM2pOR0lLUmJuNThEa0dKVGdGTGozSDk1ajA4akQ0ZlcKZ3daVGFLTmRjcmVtCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
  cluster_iam_role_arn            = "arn:aws:iam::310378384655:role/testdb09-eks-master-dev"
  aws_iam_openid_connect_provider = "arn:aws:iam::310378384655:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/DECAA7B26578A89860C3ED8F1C5F6C59"
  aws_iam_openid_url              = "oidc.eks.us-east-1.amazonaws.com/id/DECAA7B26578A89860C3ED8F1C5F6C59"
}

namespace               = "weaviate"
weaviate_replicas       = 3
vector_dimensions       = 1536
storage_size            = "50Gi"
storage_type            = "emptydir"  # Use ephemeral storage to work around EKS networking issue
storage_class           = "gp3"
weaviate_image          = "semitechnologies/weaviate:1.25.1"
helm_release_name       = "weaviate"
create_api_key          = true
api_key_recovery_window = 7
force_delete_secrets_on_destroy = true
enable_s3_backups       = true
backup_retention_days   = 7

# Authentication and Authorization
enable_authentication   = true
weaviate_admin_users    = ["akshaya.durgapu@accenture.com"]
weaviate_readonly_users = []

# gRPC configuration
enable_grpc             = true
grpc_service_type       = "LoadBalancer"

# Security - run as non-root user
weaviate_run_as_user    = 1000
