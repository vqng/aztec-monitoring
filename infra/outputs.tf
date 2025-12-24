output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "ec2_instance_id" {
  description = "ID of the EC2 worker instance"
  value       = aws_instance.k8s_worker.id
}

output "ec2_instance_private_ip" {
  description = "Private IP of the EC2 worker instance"
  value       = aws_instance.k8s_worker.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "grafana_public_lb_url" {
  description = "Public load balancer URL for Grafana"
  value = try(
    data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname != "" ? 
      "http://${data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname}" :
      "http://${data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].ip}",
    "Load balancer not ready yet"
  )
}
