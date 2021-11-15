output "grafana_base_url" {
  value = "https://${local.grafana_host}/"
}

output "grafana_ip_address" {
  value = google_compute_global_address.grafana.*.address
}

output "alertmanager_base_url" {
  value = "https://${local.alertmanager_host}/"
}

output "alertmanager_ip_address" {
  value = google_compute_global_address.alertmanager.*.address
}

output "prometheus_base_url" {
  value = "https://${local.prometheus_host}/"
}

output "prometheus_ip_address" {
  value = google_compute_global_address.prometheus.*.address
}

output "helm_values" {
  value = helm_release.prometheus_stack.values
}

output "kube_prometheus_stack_service_account" {
  value = google_service_account.kube_prometheus_stack.email
}

output "kube_prometheus_stack_gcp_service_account" {
  value = google_service_account.kube_prometheus_stack.name
}

output "kube_prometheus_stack_gcp_service_account_email" {
  value = google_service_account.kube_prometheus_stack.email
}

output "kube_prometheus_stack_k8s_service_account" {
  value = kubernetes_service_account.kube_prometheus_stack.metadata.0.name
}

output "pushgateway_endpoint" {
  value = "pushgateway-prometheus-pushgateway.${var.namespace}.svc.cluster.local"
}