#!/bin/bash
set -e

# Detect the default user (ec2-user for Amazon Linux, ubuntu for Ubuntu, etc.)
# For EKS-optimized AMIs (Amazon Linux 2), this will be ec2-user
DEFAULT_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}')

# Fallback to ec2-user if detection fails (for Amazon Linux 2 EKS AMIs)
if [ -z "$DEFAULT_USER" ] || [ ! -d "/home/$DEFAULT_USER" ]; then
  DEFAULT_USER="ec2-user"
fi

# Configure AWS CLI region
aws configure set region ${aws_region}

# Create kubeconfig directory
mkdir -p /home/$DEFAULT_USER/.kube
chown $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/.kube

# Configure kubectl to connect to EKS cluster
aws eks update-kubeconfig \
  --region ${aws_region} \
  --name ${cluster_name} \
  --kubeconfig /home/$DEFAULT_USER/.kube/config

# Set proper permissions
chown -R $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/.kube
chmod 600 /home/$DEFAULT_USER/.kube/config

# Verify kubectl can connect to the cluster
echo "Verifying cluster connection..."
kubectl --kubeconfig /home/$DEFAULT_USER/.kube/config cluster-info || true

# Log completion
echo "User data script completed at $(date)" >> /var/log/user-data.log

