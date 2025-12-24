# AWS EKS Cluster Terraform Configuration

This Terraform configuration provisions a lightweight AWS EKS cluster within a VPC, including an additional EC2 worker node. It automates the deployment of the following monitoring stack:

* **[grafana/grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana):** For metrics visualization and dashboards.
* **[VictoriaMetrics/helm-charts](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-single):** A single-node installation for efficient time-series storage.
* **`aztec-gh-exporter`:** A custom local chart included to export GitHub Actions metrics.

## Design & Principles

While this project is a Proof of Concept (PoC) rather than a production-hardened release, it demonstrates key DevOps principles essential for modern infrastructure:

* **Infrastructure as Code (IaC):** The entire environment is provisioned from scratch using Terraform v1.14.3. Grafana dashboards and configurations are codified and stored in version control, ensuring reproducibility.
* **Security:** Network isolation is prioritized. All services are provisioned within a private VPC context, with only the Grafana interface exposed publicly via a Load Balancer.
* **Observability:** Metrics are actively pushed to the VictoriaMetrics server, with pre-configured graphs available immediately in Grafana.
* **Reliability:** Kubernetes manages the cluster state and automatically recreates pods in the event of failure. Backend resilience can be further improved by increasing chart replica counts for high availability.

## Prerequisites

1.  **AWS CLI** configured with appropriate credentials.
2.  **Terraform >= 1.14.3** installed.
3.  **`kubectl`** installed.

## Setup

1.  **Configure Variables**
    Copy the example variables file:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```
    Edit `terraform.tfvars` to add your specific configuration (e.g., `GITHUB_TOKEN`, custom Grafana credentials).

2.  **Initialize Terraform**
    ```bash
    terraform init
    ```

3.  **Review Plan**
    Generate and view the execution plan:
    ```bash
    terraform plan
    ```

4.  **Apply Configuration**
    Provision the infrastructure:
    ```bash
    terraform apply
    ```

5.  **Access Grafana**
    Retrieve the Load Balancer URL from the output:
    ```bash
    terraform output
    # ...
    # grafana_public_lb_url = "http://a5e9dabe4c370497fae772103443c91e-649800778.us-east-1.elb.amazonaws.com"
    ```
    * Navigate to the URL in your browser.
    * Login with `admin:admin` (or your custom credentials).
    * Go to **Dashboards** > **Aztec GitHub Actions Workflow Dashboard**.

## Resources Created

* **VPC:** Custom VPC with public and private subnets distributed across 2 availability zones.
* **EKS Cluster:** Managed Kubernetes cluster with a default node group (1 node).
* **Worker Node:** An additional, optimized EC2 instance (`t3.medium`) configured as a worker node.
* **Load Balancer:** A public Network Load Balancer (NLB) for Grafana access.
* **IAM & Security:** All necessary IAM roles, policies, and Security Groups.
