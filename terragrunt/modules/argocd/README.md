# ArgoCD Module

Deploys ArgoCD to EKS cluster using Helm with GitOps configuration.

## Resources Created

- ArgoCD Helm release
- ArgoCD server service (LoadBalancer)
- GitHub repository secret for GitOps
- ArgoCD applications (app-of-apps pattern)
- RBAC configuration for ArgoCD

## Usage

```hcl
terraform {
  source = "../../../modules/argocd"
}

dependency "eks" {
  config_path = "../eks"
}

inputs = {
  environment     = "dev"
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  github_repo_url = "https://github.com/your-org/your-repo"
  github_token    = var.github_token
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | - |
| cluster_name | EKS cluster name | string | - |
| cluster_endpoint | EKS cluster endpoint | string | - |
| cluster_certificate_authority_data | EKS cluster CA data | string | - |
| github_repo_url | GitHub repository URL | string | - |
| github_token | GitHub token for repo access | string | - |
| argocd_namespace | ArgoCD namespace | string | "argocd" |

## Outputs

| Name | Description |
|------|-------------|
| argocd_server_url | ArgoCD server URL |
| argocd_admin_password | ArgoCD admin password |
| argocd_namespace | ArgoCD namespace |

## Post-Deployment

1. Get ArgoCD admin password:
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
   ```

2. Port-forward to access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. Access ArgoCD at https://localhost:8080 (admin/password)
