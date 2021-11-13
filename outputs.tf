output "grafana_base_url" {
  value = "https://${local.grafana_host}/"
}

output "helm_values" {
  value = helm_release.prometheus_stack.values
}

output "kube_prometheus_stack_service_account" {
  value = google_service_account.kube_prometheus_stack.email
}

output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata.0.name
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
  value = "pushgateway-prometheus-pushgateway.${kubernetes_namespace.monitoring.metadata.0.name}.svc.cluster.local"
}