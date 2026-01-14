terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.15.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
  }
}

data "google_client_config" "default" {}

provider "kubectl" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}
provider "helm" {
  # Configuration options
  kubernetes = {
    host                   = google_container_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

provider "google" {
  # Configuration options
  project = var.project_id
  region  = var.region
}
resource "google_compute_network" "primary" {
  name                    = "crossplane-network"
  auto_create_subnetworks = false

}
resource "google_compute_subnetwork" "primary" {
  name          = "crossplane-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.primary.id
}
resource "google_compute_router" "router" {
  name    = "crossplane-router"
  region  = var.region
  network = google_compute_network.primary.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "crossplane-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
resource "google_container_cluster" "primary" {
  name               = "crossplane-cluster"
  location           = var.region
  network            = google_compute_network.primary.name
  subnetwork         = google_compute_subnetwork.primary.name
  initial_node_count = 1
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    machine_type = "e2-medium"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "109.49.240.143/32"
      display_name = "my-home-ip"
    }
  }
}

resource "google_service_account" "crossplane_sa" {
  account_id   = "crossplane-sa"
  display_name = "Crossplane Service Account"
}

resource "google_project_iam_member" "crossplane_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.crossplane_sa.email}"
}

resource "google_project_iam_member" "crossplane_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.crossplane_sa.email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.crossplane_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[crossplane-system/provider-gcp-default]"
}

resource "helm_release" "crossplane" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  namespace        = "crossplane-system"
  create_namespace = true
}


resource "kubectl_manifest" "deployment_runtime_config" {
  yaml_body  = <<YAML
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: workload-identity-runtimeconfig
spec:
  serviceAccountTemplate:
    metadata:
      annotations:
        iam.gke.io/gcp-service-account: ${google_service_account.crossplane_sa.email}
YAML
  depends_on = [helm_release.crossplane]
}

resource "kubectl_manifest" "provider_gcp" {
  yaml_body = <<YAML
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-storage
spec:
  package: xpkg.upbound.io/upbound/provider-gcp-storage:v2.1.0
  runtimeConfigRef:
    name: workload-identity-runtimeconfig
YAML
}

# Auth configuration
resource "kubectl_manifest" "provider_config" {
  yaml_body = <<YAML
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: "${var.project_id}"
  credentials:
    source: InjectedIdentity
YAML
}
