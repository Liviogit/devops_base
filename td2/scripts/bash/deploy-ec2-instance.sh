#!/usr/bin/env bash

set -e

export AWS_DEFAULT_REGION="us-east-2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_data=$(cat "$SCRIPT_DIR/user-data.sh")

SECURITY_GROUP_NAME="sample-app"

# Vérifier si le Security Group existe déjà
existing_security_group_id=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [ "$existing_security_group_id" == "None" ]; then
  echo "Création du Security Group..."
  security_group_id=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Allow HTTP traffic into the sample app" \
    --output text \
    --query GroupId)

  echo "Security Group créé avec l'ID : $security_group_id"

  aws ec2 authorize-security-group-ingress \
    --group-id "$security_group_id" \
    --protocol tcp \
    --port 80 \
    --cidr "0.0.0.0/0" > /dev/null
else
  echo "Le Security Group existe déjà : $existing_security_group_id"
  security_group_id=$existing_security_group_id
fi

# Lancer une instance EC2 avec le Security Group
instance_id=$(aws ec2 run-instances \
  --image-id "ami-0900fe555666598a2" \
  --instance-type "t2.micro" \
  --security-group-ids "$security_group_id" \
  --user-data "$user_data" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-app}]' \
  --output text \
  --query Instances[0].InstanceId)

# Récupérer l'adresse IP publique de l'instance
public_ip=$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --output text \
  --query 'Reservations[*].Instances[*].PublicIpAddress')

echo "Instance ID = $instance_id"
echo "Security Group ID = $security_group_id"
echo "Public IP = $public_ip"
