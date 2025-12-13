output "dev_account_id" {
  value = aws_organizations_account.dev.id
}

output "staging_account_id" {
  value = aws_organizations_account.staging.id
}

output "production_account_id" {
  value = aws_organizations_account.production.id
}

# Use OrganizationAccountAccessRole which is created automatically
output "dev_account_role_arn" {
  value = "arn:aws:iam::${aws_organizations_account.dev.id}:role/OrganizationAccountAccessRole"
}

output "staging_account_role_arn" {
  value = "arn:aws:iam::${aws_organizations_account.staging.id}:role/OrganizationAccountAccessRole"
}

output "production_account_role_arn" {
  value = "arn:aws:iam::${aws_organizations_account.production.id}:role/OrganizationAccountAccessRole"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
