# Crossplane Infrastructure

This repository contains infrastructure as code for deploying and managing Crossplane on Google Cloud Platform (GCP) using Terraform.

## Overview

This project sets up:

- A GKE (Google Kubernetes Engine) cluster
- Crossplane installation via Helm
- GCP provider configuration for Crossplane
- Example infrastructure resources managed by Crossplane

## Architecture

The infrastructure consists of:

- **GCP Network**: Custom VPC network with subnet
- **GKE Cluster**: Kubernetes cluster for running Crossplane
- **Crossplane**: Installed via Helm chart for infrastructure orchestration
- **GCP Provider**: Enables Crossplane to manage GCP resources

## Prerequisites

Before you begin, ensure you have:

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with appropriate credentials
- A GCP project with the following APIs enabled:
  - Compute Engine API
  - Kubernetes Engine API
  - Cloud Resource Manager API
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for interacting with the cluster

## Configuration

### Required Variables

Create a `terraform.tfvars` file (not tracked in git) with:

```hcl
project_id = "your-gcp-project-id"
region     = "europe-west1"  # Optional, defaults to europe-west1
```

## Usage

### Initial Setup

1. **Authenticate with GCP:**

   ```bash
   gcloud auth application-default login
   ```

2. **Initialize Terraform:**

   ```bash
   terraform init
   ```

3. **Review the deployment plan:**

   ```bash
   terraform plan
   ```

4. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

### Accessing the Cluster

After deployment, configure kubectl to access the cluster:

```bash
gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region $(terraform output -raw region)
```

### Verify Crossplane Installation

```bash
kubectl get pods -n crossplane-system
```

### Managing Resources with Crossplane

Example: Create a GCS bucket using Crossplane:

```bash
kubectl apply -f bucket.yaml
```

Check the status:

```bash
kubectl get bucket
kubectl describe bucket crossplane-test-2026-v1-unique
```

## Project Structure

```
.
├── main.tf              # Main Terraform configuration
├── variables.tf         # Variable definitions
├── terraform.tfvars     # Variable values (gitignored)
├── bucket.yaml          # Example Crossplane resource
├── .gitignore          # Git ignore rules
└── README.md           # This file
```

## Resources Created

### Terraform Resources

- `google_compute_network`: VPC network
- `google_compute_subnetwork`: Subnet for the GKE cluster
- `google_container_cluster`: GKE cluster
- `helm_release`: Crossplane installation
- `kubectl_manifest`: Crossplane provider configuration

### Crossplane Resources

- GCP Provider configuration
- Example: Storage Bucket (bucket.yaml)

## Cleanup

To destroy all resources:

```bash
# First delete Crossplane-managed resources
kubectl delete -f bucket.yaml

# Wait for resources to be cleaned up, then destroy Terraform resources
terraform destroy
```

**Note:** Always delete Crossplane-managed resources before destroying the Terraform infrastructure to ensure proper cleanup.

## Security Notes

- Never commit `terraform.tfvars`, `*.tfstate`, or other sensitive files
- Use service accounts with minimum required permissions
- Consider using Google Cloud Secret Manager for sensitive values
- Review and adjust network security rules as needed

## Troubleshooting

### Crossplane pods not starting

```bash
kubectl logs -n crossplane-system -l app=crossplane
```

### Provider configuration issues

```bash
kubectl describe providerconfig default
kubectl get providers
```

### GKE cluster access issues

Ensure your gcloud configuration is correct:

```bash
gcloud config list
gcloud auth list
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
