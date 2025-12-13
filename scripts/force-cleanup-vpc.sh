#!/bin/bash

# Force cleanup script for stuck VPC resources during Terraform destroy
# Usage: ./scripts/force-cleanup-vpc.sh <vpc-id> [aws-profile] [region]

set -e

VPC_ID=${1:-}
AWS_PROFILE=${2:-oth_infra}
REGION=${3:-eu-central-1}

if [ -z "$VPC_ID" ]; then
    echo "Usage: $0 <vpc-id> [aws-profile] [region]"
    echo "Example: $0 vpc-0c890fbfd04301819 oth_infra eu-central-1"
    exit 1
fi

export AWS_PROFILE=$AWS_PROFILE

echo "🧹 Force cleaning VPC resources: $VPC_ID"
echo "Profile: $AWS_PROFILE, Region: $REGION"

# 1. Delete Classic Load Balancers
echo "1️⃣ Deleting Classic Load Balancers..."
aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | \
while read -r lb_name; do
    if [ -n "$lb_name" ]; then
        echo "  Deleting ELB: $lb_name"
        aws elb delete-load-balancer --load-balancer-name "$lb_name" --region $REGION
    fi
done

# 2. Delete Application Load Balancers
echo "2️⃣ Deleting Application Load Balancers..."
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
while read -r lb_arn; do
    if [ -n "$lb_arn" ]; then
        echo "  Deleting ALB: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION
    fi
done

# 3. Terminate EC2 instances
echo "3️⃣ Terminating EC2 instances..."
aws ec2 describe-instances --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text | \
while read -r instance_id; do
    if [ -n "$instance_id" ]; then
        echo "  Terminating instance: $instance_id"
        aws ec2 terminate-instances --instance-ids "$instance_id" --region $REGION
    fi
done

# 4. Wait for instances to terminate
echo "4️⃣ Waiting for instances to terminate..."
sleep 10

# 5. Force cleanup stuck ENIs
echo "5️⃣ Force cleaning network interfaces..."
aws ec2 describe-network-interfaces --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkInterfaces[?Status=='in-use'].[NetworkInterfaceId,Attachment.AttachmentId]" --output text | \
while read -r eni_id attachment_id; do
    if [ -n "$eni_id" ] && [ -n "$attachment_id" ]; then
        echo "  Force detaching ENI: $eni_id"
        aws ec2 detach-network-interface --attachment-id "$attachment_id" --region $REGION --force || true
        sleep 2
        echo "  Deleting ENI: $eni_id"
        aws ec2 delete-network-interface --network-interface-id "$eni_id" --region $REGION || true
    fi
done

# 6. Delete NAT Gateways
echo "6️⃣ Deleting NAT Gateways..."
aws ec2 describe-nat-gateways --region $REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query "NatGateways[].NatGatewayId" --output text | \
while read -r nat_id; do
    if [ -n "$nat_id" ]; then
        echo "  Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region $REGION
    fi
done

# 7. Delete Internet Gateways
echo "7️⃣ Detaching Internet Gateways..."
aws ec2 describe-internet-gateways --region $REGION \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query "InternetGateways[].InternetGatewayId" --output text | \
while read -r igw_id; do
    if [ -n "$igw_id" ]; then
        echo "  Detaching IGW: $igw_id"
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$VPC_ID" --region $REGION || true
        echo "  Deleting IGW: $igw_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region $REGION || true
    fi
done

echo "✅ Force cleanup complete! Terraform destroy should now proceed."
echo "💡 Run: terraform destroy -auto-approve"
