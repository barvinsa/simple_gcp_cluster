# before running terraform, login into gcp via gcloud init
num_clusters = 3
project_name = ""
project_id = ""
labels = { "tag1" = "value1", "tag2"  = "value2" }
billing_account = ""
org_id = ""
location = "us-east1"
k8s_cluster_name = "test-cluster"
node_pool_name = "test-node-pool"
machine_type = "e2-medium"