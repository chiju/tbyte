# Additional providers for cross-account role creation
provider "aws" {
  alias  = "dev"
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.dev.id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "staging"
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.staging.id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "production"
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.production.id}:role/OrganizationAccountAccessRole"
  }
}
