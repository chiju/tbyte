# Shared Services: ECR repositories in root account

module "ecr" {
  source = "../ecr"

  cluster_name = var.cluster_name
  environment  = var.environment
}
