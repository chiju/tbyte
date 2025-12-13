# Shared Services: ECR repositories in root account

module "ecr" {
  source = "../../modules/ecr"

  cluster_name = "tbyte"
  environment  = var.environment
}
