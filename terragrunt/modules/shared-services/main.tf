# Shared Services: ECR repositories in root account

module "ecr" {
  source = "../ecr"

  cluster_name = "tbyte"
  environment  = var.environment
}
