#!/bin/bash

# Check EKS access entries for tbyte-dev cluster

echo "🔍 Checking EKS access entries..."

# Assume dev account role and check access entries
AWS_PROFILE=oth_infra aws sts assume-role \
  --role-arn "arn:aws:iam::045129524082:role/OrganizationAccountAccessRole" \
  --role-session-name "check-access" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | {
  read access_key secret_key session_token
  
  export AWS_ACCESS_KEY_ID=$access_key
  export AWS_SECRET_ACCESS_KEY=$secret_key
  export AWS_SESSION_TOKEN=$session_token
  
  echo "📋 Access Entries:"
  aws eks list-access-entries --cluster-name tbyte-dev --region eu-central-1
  
  echo ""
  echo "🔐 Access Policies for OrganizationAccountAccessRole:"
  aws eks list-associated-access-policies \
    --cluster-name tbyte-dev \
    --principal-arn "arn:aws:iam::045129524082:role/OrganizationAccountAccessRole" \
    --region eu-central-1 2>/dev/null || echo "No policies found"
}
