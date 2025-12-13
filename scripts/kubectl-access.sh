#!/bin/bash

# Access EKS cluster with kubectl using cross-account role

echo "🔧 Setting up kubectl access to tbyte-dev cluster..."

# Assume dev account role and configure kubectl
AWS_PROFILE=oth_infra aws sts assume-role \
  --role-arn "arn:aws:iam::045129524082:role/OrganizationAccountAccessRole" \
  --role-session-name "kubectl-access" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | {
  read access_key secret_key session_token
  
  export AWS_ACCESS_KEY_ID=$access_key
  export AWS_SECRET_ACCESS_KEY=$secret_key
  export AWS_SESSION_TOKEN=$session_token
  
  echo "📋 Updating kubeconfig..."
  aws eks update-kubeconfig --name tbyte-dev --region eu-central-1
  
  echo "🚀 Testing cluster access..."
  kubectl get nodes
  
  echo ""
  echo "📦 Checking pods..."
  kubectl get pods --all-namespaces
}
