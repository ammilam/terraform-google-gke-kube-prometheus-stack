variable "dns_managed_zone" {
  type        = string
  default     = ""
  description = "company Internal DNS Managed Zone"
}

variable "dns_public_zone" {
  type        = string
  default     = ""
  description = "Public Managed Zone"
}

variable "namespace" {
  type        = string
  description = "Namespace to install kube-prometheus-stack and related resources into"
}

variable "dns_name" {
  type        = string
  default     = ""
  description = "Name of the DNS Managed Zone Resource"
}

variable "env" {
  type        = string
  default     = "prod"
  description = "prod|non-prod"
}

variable "dns_public_zone_project_id" {
  type        = string
  default     = ""
  description = "Project containing the Public DNS Managed Zone"
}

variable "dns_managed_zone_project_id" {
  type        = string
  default     = ""
  description = "Project containing the Private DNS Managed Zone"
}
variable "project_id" {
  type        = string
  description = "Project that contains the GKE cluster to deploy prometheus-stack into"
}

variable "metrics_scope_project_id" {
  type        = string
  description = "Monitoring Scope Project"
}

variable "prometheus_resource_cpu_limit" {
  type        = string
  description = "Prometheus pod cpu limit"
  default     = "1"
}

variable "prometheus_resource_cpu_requests" {
  type        = string
  description = "Prometheus pod cpu requests"
  default     = "500m"
}

variable "prometheus_resource_memory_limit" {
  type        = string
  description = "Prometheus pod memory limit"
  default     = "4Gi"
}

variable "prometheus_resource_memory_requests" {
  type        = string
  description = "Prometheus pod memory requests"
  default     = "2Gi"
}

variable "prometheus_retention_size_gb" {
  type        = string
  description = "Prometheus retention size"
  default     = "50"
}

variable "prometheus_ingress_enabled" {
  type    = bool
  default = false
}

variable "prometheus_replicas" {
  type        = number
  description = "Count of Prometheus replicas"
  default     = 2
}

variable "prometheus_enabled" {
  type    = bool
  default = true
}

variable "prometheus_log_level" {
  type    = string
  default = "info"
}

variable "alertmanager_enabled" {
  type    = bool
  default = true
}

variable "alertmanager_replicas" {
  type        = number
  description = "Count of Alertmanager replicas"
  default     = 1
}

variable "alertmanager_log_level" {
  type    = string
  default = "info"
}

variable "alertmanager_resource_cpu_limit" {
  type        = string
  description = "Alertmanager pod cpu limit"
  default     = "500m"
}

variable "alertmanager_resource_cpu_requests" {
  type        = string
  description = "Alertmanager pod cpu requests"
  default     = "200m"
}

variable "alertmanager_resource_memory_limit" {
  type        = string
  description = "Alertmanager pod memory limit"
  default     = "256Mi"
}

variable "alertmanager_resource_memory_requests" {
  type        = string
  description = "Alertmanager pod memory requests"
  default     = "128Mi"
}

variable "alertmanager_ingress_enabled" {
  type    = bool
  default = false
}
variable "grafana_enabled" {
  type    = bool
  default = true
}

variable "grafana_dashboard_label" {
  type        = string
  default     = "grafana_dashboard"
  description = "label used to provision grafana dashboards"
}
variable "grafana_ingress_enabled" {
  type    = bool
  default = false
}

variable "grafana_replicas" {
  type        = number
  description = "Count of Grafana replicas"
  default     = 1
}

variable "grafana_resource_cpu_limit" {
  type        = string
  description = "Grafana pod cpu limit"
  default     = "500m"
}

variable "grafana_resource_cpu_requests" {
  type        = string
  description = "Grafana pod cpu requests"
  default     = "200m"
}

variable "grafana_resource_memory_limit" {
  type        = string
  description = "Grafana pod memory limit"
  default     = "256Mi"
}

variable "grafana_resource_memory_requests" {
  type        = string
  description = "Grafana pod memory requests"
  default     = "128Mi"
}

variable "grafana_tls_cert" {
  description = "Grafana TLS certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_tls_private_key" {
  description = "Grafana TLS private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "prometheus_tls_cert" {
  description = "Prometheus TLS certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "prometheus_tls_private_key" {
  description = "Prometheus TLS private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alertmanager_tls_cert" {
  description = "Alertmanager TLS certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alertmanager_tls_private_key" {
  description = "Alertmanager TLS private key"
  type        = string
  sensitive   = true
  default     = ""
}


variable "grafana_oauth_client_id" {
  description = "Grafana OAuth client ID"
  type        = string
  sensitive   = true // TODO Is this right?
  default     = ""
}

variable "grafana_oauth_client_secret" {
  description = "Grafana OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_admin_password" {
  type        = string
  description = "admin password for grafana"
  default     = "prom-operator"
}

variable "grafana_google_auth_enabled" {
  type        = bool
  description = "If set to true, this will enable OAUTH with company google credentials"
  default     = false
}

variable "prometheus_to_stackdriver_enabled" {
  type        = bool
  default     = false
  description = "Adds stackdriver sidecar container to prometheus to send metrics to GCP"
}

variable "stackdriver_metrics_filter" {
  type        = list(string)
  default     = [""]
  description = "Pass in stackdriver metrics for a filter"
}

variable "gke_cluster_name" {
  type        = string
  description = "Name of the GKE cluster, only necessary if prometheus_to_stackdriver_enabled is set to true"
}

variable "google_managed_cert" {
  type        = bool
  default     = false
  description = "Will pass a google managed cert to the gce ingress configs"
}

variable "enable_alertmanager_cloudfunction_routing" {
  type        = bool
  default     = false
  description = "If set to true, this will enable alertmanager to forward alerts to the alert routing cloud function"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "alertmanager_chat_receiver_object" {
  type    = any
  default = {}
}

variable "enable_calert" {
  type        = bool
  default     = false
  description = "Enables calert for google chat alert routing"
}

variable "enable_prometheus_webexteams" {
  description = "Whether to enable Prometheus-WebexTeams for WebEx chat room alert routing"
  type        = bool
  default     = false
}

variable "alertmanager_alert_chat_channels" {
  description = "alert channels for a chat client"
  type        = any
  default     = [""]
}

variable "alertmanager_alert_webex_teams_channels" {
  description = "alert channels for a chat client"
  type        = any
  default     = [""]
}


variable "prom_stack_common_label" {
  type        = string
  default     = "default"
  description = "label added to all resources created via kube-prometheus-stack helm chart, helps with prometheus rule ingestion"
}


variable "prometheus_scrape_configs" {
  type        = any
  description = "additional scrape configs for prometheus"
  default     = [""]
}

variable "alertmanager_alerts_to_silence" {
  type        = string
  description = "Alertmanager alerts to send to blackhole"
  default     = ""
}


variable "rbac" {
  type        = bool
  default     = true
  description = "enable or disable rbac for prometheus stack"
}

variable "grafana_plugins" {
  type        = any
  default     = [""]
  description = "list of grafana plugins to install"
}

variable "prometheus_retention_length" {
  type        = string
  default     = "14d"
  description = "length to keep scraped metrics in prometheus for visualization"
}

variable "suffix" {
  type = string
}

variable "grafana_additional_datasources" {
  type    = string
  default = ""
}

variable "google_application_credentials_secret" {
  type    = string
  default = ""
}


variable "monitoring_service_account_email" {
  type    = string
  default = ""
}

variable "monitoring_service_account_email_name" {
  type    = string
  default = ""
}

variable "pushgateway_enabled" {
  type    = bool
  default = false
}

variable "pushgateway_resource_cpu_limit" {
  type        = string
  description = "pushgateway pod cpu limit"
  default     = "2"
}

variable "pushgateway_resource_cpu_requests" {
  type        = string
  description = "pushgateway pod cpu requests"
  default     = "1"
}

variable "pushgateway_resource_memory_limit" {
  type        = string
  description = "pushgateway pod memory limit"
  default     = "8Gi"
}

variable "pushgateway_resource_memory_requests" {
  type        = string
  description = "pushgateway pod memory requests"
  default     = "6Gi"
}