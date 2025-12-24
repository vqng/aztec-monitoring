# VPC for EKS cluster
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Enable access to the cluster for the creator
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# EC2 Instance (c8a.medium equivalent - using c8a.large as c8a.medium doesn't exist)
resource "aws_instance" "k8s_worker" {
  ami           = data.aws_ami.eks_optimized.id
  instance_type = var.ec2_instance_type

  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_instance.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_instance.name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region = var.aws_region
    cluster_name = var.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_ca = module.eks.cluster_certificate_authority_data
  }))

  tags = {
    Name        = "${var.cluster_name}-worker"
    Environment = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_instance" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.cluster_name}-worker-sg"
  }
}

# Allow all traffic from VPC
resource "aws_security_group_rule" "ec2_instance_vpc_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.ec2_instance.id
  description       = "Allow all traffic from VPC"
}

# Allow all outbound traffic
resource "aws_security_group_rule" "ec2_instance_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_instance.id
  description       = "Allow all outbound traffic"
}

# Allow EC2 instance to communicate with EKS cluster
resource "aws_security_group_rule" "eks_to_ec2" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.ec2_instance.id
  description              = "Allow traffic from EKS cluster"
}

resource "aws_security_group_rule" "ec2_to_eks" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_instance.id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow traffic from EC2 worker instance"
}

# Data source to find the EKS node security group
# EKS managed node groups use a shared security group
data "aws_security_groups" "eks_nodes" {
  filter {
    name   = "tag:Name"
    values = ["*eks*node*"]
  }
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
}

# Allow LoadBalancer traffic to EKS nodes
# For Classic Load Balancers, nodes need to accept traffic from the LB security group
# The LoadBalancer security group ID is: sg-01b5f949c56df8e01
# We need to allow traffic on the NodePort range (30000-32767) from the LB to the nodes
resource "aws_security_group_rule" "loadbalancer_to_nodes" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = "sg-01b5f949c56df8e01"  # LoadBalancer security group
  security_group_id        = length(data.aws_security_groups.eks_nodes.ids) > 0 ? data.aws_security_groups.eks_nodes.ids[0] : module.eks.cluster_security_group_id
  description              = "Allow LoadBalancer traffic to EKS nodes (NodePort range)"
}

# IAM Role for EC2 Instance to join EKS cluster
resource "aws_iam_role" "ec2_instance" {
  name = "${var.cluster_name}-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_instance_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ec2_instance.name
}

resource "aws_iam_role_policy_attachment" "ec2_instance_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ec2_instance.name
}

resource "aws_iam_role_policy_attachment" "ec2_instance_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ec2_instance.name
}

resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${var.cluster_name}-worker-profile"
  role = aws_iam_role.ec2_instance.name
}

# Data source for EKS-optimized AMI
data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-${var.kubernetes_version}-v*"]
  }
}

