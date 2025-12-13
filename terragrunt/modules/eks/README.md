# EKS Module

Creates a production-ready EKS cluster with managed node groups, IRSA, and essential add-ons.

## Resources Created

- EKS Cluster (v1.34)
- Managed Node Group with auto-scaling
- OIDC Provider for IRSA
- Essential EKS Add-ons (VPC CNI, CoreDNS, kube-proxy, metrics-server, EBS CSI)
- Karpenter for intelligent node scaling
- IAM roles for cluster, nodes, and service accounts
- Security groups and access entries

## Usage

```hcl
terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  environment             = "dev"
  cluster_name            = "tbyte-dev"
  kubernetes_version      = "1.34"
  public_subnet_ids       = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  node_instance_type      = "t3.small"
  desired_nodes           = 1
  min_nodes               = 1
  max_nodes               = 3
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | - |
| cluster_name | EKS cluster name | string | - |
| kubernetes_version | Kubernetes version | string | "1.34" |
| public_subnet_ids | Public subnet IDs | list(string) | - |
| private_subnet_ids | Private subnet IDs | list(string) | - |
| node_instance_type | EC2 instance type for nodes | string | "t3.medium" |
| desired_nodes | Desired number of nodes | number | 2 |
| min_nodes | Minimum number of nodes | number | 1 |
| max_nodes | Maximum number of nodes | number | 4 |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_endpoint | EKS cluster endpoint |
| cluster_certificate_authority_data | EKS cluster CA data |
| cluster_security_group_id | EKS cluster security group ID |
| oidc_provider_arn | OIDC provider ARN for IRSA |
| karpenter_controller_role_arn | Karpenter controller IAM role ARN |
| grafana_cloudwatch_role_arn | Grafana CloudWatch IAM role ARN |
