# AWS EKS Cluster Terraform Configuration

This Terraform configuration provisions a small AWS EKS cluster in a VPC with an additional EC2 worker node.
It then installs three Helm charts:
- [grafana/grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana) (for dashboards)
- [VictoriaMetrics/helm-charts (victoria-metrics-single)](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-single) (for time-series storage)
- `aztec-gh-exporter` (custom chart included locally for GitHub Actions metrics exporter)

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.14.3 installed
3. `kubectl` installed

## Setup

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your desired configuration (`GITHUB_TOKEN`, default credentials for grafana)

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the execution plan:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

6. Navigate to the Grafana LB:
   ```bash
   terraform output
   ...
   grafana_public_lb_url = "http://a5e9dabe4c370497fae772103443c91e-649800778.us-east-1.elb.amazonaws.com"
   ...
   ```

   Then login with `admin:admin` (or the credentials customized above).

   Go to `/dashboards` and `Aztec GitHub Actions Workflow Dashboard`

## Resources Created

- VPC with public and private subnets across 2 availability zones
- EKS cluster with a managed node group (1 node by default)
- Additional EC2 instance (c8a.large) configured as a worker node
- Required IAM roles and policies
- Security groups
- Public NLB for Grafana

## Design and Principles 
Due to time constraints, this project aims to demonstrate the key modern DevOps principles to be used in production. It is not a production grade yet.

- Infrastructure as Code: The whole project can be provisioned in a fresh AWS account with Terraform v1.14.3. Grafana dashboards and configurations are also checked in into repo.
- Security: The services are provisioned in a VPC, only Grafana is exposed through an ALB
- Observability: two metrics are being pushed to VictoriaMetrics server, graphs are configured in Grafana
- Reliabilty: Kubernetes manages the cluster and shall recreate pods if one fails. The backend can be stored by going with multi replica charts and increase the replicas count.
