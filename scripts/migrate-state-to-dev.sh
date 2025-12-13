#!/bin/bash

# Migrate state from root account to dev account
set -e

ROOT_BUCKET="tbyte-terragrunt-state-432801802107"
DEV_BUCKET="tbyte-terragrunt-state-045129524082"

echo "🔄 Migrating state from root account to dev account..."

# Copy all state files from root bucket to dev bucket
echo "📋 Copying state files..."
AWS_PROFILE=oth_infra aws s3 sync s3://$ROOT_BUCKET s3://$DEV_BUCKET --region eu-central-1

echo "✅ State migration complete!"
echo ""
echo "📊 State files in dev account:"
aws s3 ls s3://$DEV_BUCKET --recursive --profile oth_infra
