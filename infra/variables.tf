variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "aztec-k8s-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "node_instance_type" {
  description = "Instance type for EKS managed node group"
  type        = string
  default     = "t3.medium"
}

variable "ec2_instance_type" {
  description = "Instance type for the additional EC2 worker node (c8a.medium doesn't exist, using c8a.large)"
  type        = string
  default     = "c8a.large"
}

variable "grafana_replicas" {
  description = "Number of Grafana replicas (1 for dev, 2+ for HA with shared storage)"
  type        = number
  default     = 1
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for Monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "victoriametrics_port" {
  description = "Port for the VictoriaMetrics service (ClusterIP)"
  type        = number
  default     = 3080
}

variable "github_token" {
  description = "GitHub token for the aztec-gh-exporter"
  type        = string
  sensitive   = true
}


