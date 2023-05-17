provider "google" {
}

resource "random_string" "random_prefix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = false
}

resource "google_project" "my_project" {
  name            = "${var.project_name}-${random_string.random_prefix.result}"
  project_id      = "${var.project_id}-${random_string.random_prefix.result}"
  labels          = var.labels
  org_id          = var.org_id
  billing_account = var.billing_account
}


resource "google_project_service" "container" {
  project = google_project.my_project.project_id
  service = "container.googleapis.com"
}

resource "google_container_cluster" "artem-tf-cluster" {
  count    = var.num_clusters
  project  = google_project.my_project.project_id
  name     = "${var.k8s_cluster_name}-${count.index}-${random_string.random_prefix.result}"
  location = var.location
  remove_default_node_pool = true
  initial_node_count       = 1
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
  depends_on = [ google_project_service.container ]
}

resource "google_container_node_pool" "primary_notes_pool" {
  count      = var.num_clusters
  name       = var.node_pool_name
  location   = var.location
  cluster    = google_container_cluster.artem-tf-cluster[count.index].name
  project    = google_project.my_project.project_id
  autoscaling {
    # min_node_count = 1
    # max_node_count = 1
    total_max_node_count = 9
    total_min_node_count = 3
  }
  node_config {
    preemptible  = true
    machine_type = var.machine_type
  }
  depends_on = [google_project_service.container]
}

data "google_project" "dns-tsb-sandbox" {
  project_id = var.dns_project_id
}

data "google_dns_managed_zone" "gcp_sandbox" {
  project = data.google_project.dns-tsb-sandbox.project_id
  name    = "gcp-sandbox-tetrate-io"
}

resource "google_dns_record_set" "dns" {
  project = data.google_project.dns-tsb-sandbox.project_id
  name = "artem.${data.google_dns_managed_zone.gcp_sandbox.dns_name}"
  type = "A"
  ttl  = 300
  managed_zone = data.google_dns_managed_zone.gcp_sandbox.name
  rrdatas = [google_container_cluster.artem-tf-cluster[0].endpoint]  
  depends_on = [ google_container_cluster.artem-tf-cluster[0] ]
}

resource "local_file" "creds" {
  filename = "creds.sh"
  content = <<-EOT
    gcloud config set project ${google_project.my_project.project_id}
    %{ for idx, cluster in google_container_cluster.artem-tf-cluster.*.name ~}

    gcloud container clusters get-credentials --region ${var.location} ${cluster}
    kubectx ${cluster}=gke_${google_project.my_project.project_id}_${var.location}_${cluster}
    %{ endfor ~}
  EOT
}

resource "null_resource" "add_clusters_to_kubectl" {
  depends_on = [ local_file.creds ]
  provisioner "local-exec" {
    command = "chmod +x creds.sh && bash creds.sh"
  }
}

output "Project_ID" {
  value = google_project.my_project.project_id
}

output "Clusters" {
  value = google_container_cluster.artem-tf-cluster[*].name
}