
####################
# Prometheus Stack #
####################


# locals for naming resources
locals {
  env = {
    name     = terraform.workspace == "default" ? "prod" : terraform.workspace
    id       = terraform.workspace == "default" ? "prod" : terraform.workspace
    short_id = substr(terraform.workspace == "default" ? "prod" : terraform.workspace, 0, 30)
    type     = terraform.workspace == "default" ? terraform.workspace : "${substr(terraform.workspace, 0, 55)}-review"
  }
}


####################
# Shared Resources #
####################


# kubernetes service account creation with workload identity annotations
resource "kubernetes_service_account" "kube_prometheus_stack" {
  metadata {
    name      = "kube-prometheus-stack"
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.kube_prometheus_stack.email
    }
  }
  automount_service_account_token = true
}

# GSA to KSA Mapping for the monitoring sa
resource "google_service_account_iam_member" "monitoring" {
  service_account_id = google_service_account.kube_prometheus_stack.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${kubernetes_service_account.kube_prometheus_stack.metadata.0.name}]"
}

# monitoring google service account to be mapped to grafana deployment
resource "google_service_account" "kube_prometheus_stack" {
  account_id   = terraform.workspace == "default" ? "kube-prom-stack" : "kube-prom-stack-${var.suffix}"
  display_name = "kube-prometheus-stack service account"
  project      = var.metrics_scope_project_id
}


# allows for the ingestion of stackdriver data into grafana as a data source
resource "google_project_iam_member" "monitoring_viewer" {
  project = var.metrics_scope_project_id
  for_each = toset([
    "roles/monitoring.viewer",
    "roles/iam.serviceAccountTokenCreator",
  ])
  role   = each.value
  member = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}



# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "monitoring_metrics_writer" {
  project = var.metrics_scope_project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}


# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "log_writer" {
  project = var.metrics_scope_project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}

# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "resource_metadata_writer" {
  project = var.metrics_scope_project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}


# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "hosting_project_monitoring_metrics_writer" {
  project = var.project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}


# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "hosting_project_log_writer" {
  project = var.project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}


# role required for prometheus to write metrics to gcp
resource "google_project_iam_member" "hosting_project_resource_metadata_writer" {
  project = var.project_id
  count   = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.kube_prometheus_stack.email}"
}

# local variables to construct the grafana hostname and sets name for k8s secret creation containing grafana pki
locals {
  grafana_cert_name      = var.grafana_ingress_enabled == true ? "grafana-pki" : ""
  prometheus_cert_name   = var.prometheus_ingress_enabled == true ? "prometheus-pki" : ""
  alertmanager_cert_name = var.alertmanager_ingress_enabled == true ? "alertmanager-pki" : ""
  grafana_ip_name        = "global-grafana-ip-${local.env.short_id}-${var.suffix}"
  prometheus_ip_name     = "global-prometheus-ip-${local.env.short_id}-${var.suffix}"
  alertmanager_ip_name   = "global-alertmanager-ip-${local.env.short_id}-${var.suffix}"
  grafana_host           = var.grafana_ingress_enabled == true ? trimsuffix("grafana${terraform.workspace == "default" ? "" : ".${terraform.workspace}"}.${var.dns_name}", ".") : "localhost:3000"
  prometheus_host        = var.prometheus_ingress_enabled == true ? trimsuffix("prometheus${terraform.workspace == "default" ? "" : ".${terraform.workspace}"}.${var.dns_name}", ".") : "localhost:9090"
  alertmanager_host      = var.alertmanager_ingress_enabled == true ? trimsuffix("alertmanager${terraform.workspace == "default" ? "" : ".${terraform.workspace}"}.${var.dns_name}", ".") : "localhost:9093"
}


# creates a google managed cert if google_managed_cert == true
resource "helm_release" "managed_cert_controller" {
  name             = "managed-cert-contorller"
  count            = var.google_managed_cert == true ? 1 : 0
  namespace        = var.namespace
  chart            = "${path.module}/charts/managed-cert-controller"
  create_namespace = "false"
  max_history      = 10

  values = [
    <<-EOT
    namespace: ${var.namespace}
    k8sServiceAccount: ${kubernetes_service_account.kube_prometheus_stack.metadata.0.name}
    EOT
  ]
}


#################
# Grafana Infra #
#################

# Provision a Private DNS name for grafana.
resource "google_dns_record_set" "grafana" {
  project      = var.dns_managed_zone_project_id
  count        = var.grafana_ingress_enabled == true && var.dns_managed_zone != "" ? 1 : 0
  name         = "${local.grafana_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_managed_zone
  rrdatas      = [google_compute_global_address.grafana[count.index].address]
}

# Provision a Public DNS name for grafana.
resource "google_dns_record_set" "grafana_public" {
  project      = var.dns_public_zone_project_id
  count        = var.grafana_ingress_enabled == true && var.dns_public_zone != "" ? 1 : 0
  name         = "${local.grafana_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_public_zone
  rrdatas      = [google_compute_global_address.grafana[count.index].address]
}


# External IP - Manage this here because we want to ensure that it doesn't change (because DNS is not managed dynamically, yet)
resource "google_compute_global_address" "grafana" {
  count       = var.grafana_ingress_enabled == true ? 1 : 0
  project     = var.project_id
  name        = local.grafana_ip_name
  description = "Reservation for grafana IP"
}

# Create kubernetes secret to store the grafana PKI
resource "kubernetes_secret" "grafana_pki" {
  count = var.google_managed_cert == false && var.grafana_ingress_enabled == true ? 1 : 0
  metadata {
    name      = local.grafana_cert_name
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = nonsensitive(var.grafana_tls_cert)
    "tls.key" = nonsensitive(var.grafana_tls_private_key)
  }
}


# creates kubernetes secret from oauth secret data retrieved from google secrets manager
resource "kubernetes_secret" "grafana_oauth" {
  count = var.grafana_ingress_enabled == true ? 1 : 0
  metadata {
    name      = "iap-credentials"
    namespace = var.namespace
  }
  data = {
    "client_secret" = nonsensitive(var.grafana_oauth_client_secret)
    "client_id"     = nonsensitive(var.grafana_oauth_client_id)
  }
}


# creates a google managed cert if google_managed_cert == true
resource "helm_release" "grafana_managed_cert" {
  name             = local.grafana_cert_name
  count            = var.google_managed_cert == true ? 1 : 0
  namespace        = var.namespace
  chart            = "${path.module}/charts/managed-cert"
  create_namespace = "false"
  max_history      = 10

  values = [
    <<-EOT
    certName: ${local.grafana_cert_name}
    domains:
    - ${local.grafana_host}
    EOT
  ]
  depends_on = [
    helm_release.managed_cert_controller
  ]
}


# GCP Ingress Custom Resources that utilizes iap for use with google auth magic
resource "helm_release" "grafana_gcp_ingress_configs" {
  name             = "grafana"
  count            = var.grafana_ingress_enabled == true ? 1 : 0
  namespace        = var.namespace
  chart            = "${path.module}/charts/gcp-ingress-configs"
  create_namespace = "false"
  max_history      = 10
  values = [
    <<-EOT
    FrontendConfig:
      name: grafana
      spec:
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#https_redirect
        redirectToHttps:
          enabled: true
    BackendConfig:
      name: grafana
      spec:
        healthCheck:
          type: HTTP
          requestPath: /api/health
          port: 3000
      logging:
        enable: true
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#direct_health
    EOT
  ]
}

########################
# Prometheus Resources #
########################

# GCP Ingress Custom Resources that utilizes iap for use with google auth magic
resource "helm_release" "prometheus_gcp_ingress_configs" {
  name             = "prometheus"
  count            = var.prometheus_ingress_enabled == true ? 1 : 0
  namespace        = var.namespace
  chart            = "${path.module}/charts/gcp-ingress-configs"
  create_namespace = "false"
  max_history      = 10
  values = [
    <<-EOT
    FrontendConfig:
      name: prometheus
      spec:
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#https_redirect
        redirectToHttps:
          enabled: true
    BackendConfig:
      name: prometheus
      spec:
        healthCheck:
          type: HTTP
          requestPath: /-/healthy
          port: 9090
      logging:
        enable: true
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#direct_health
    EOT
  ]
}

# Provision a Private DNS name for grafana.  
resource "google_dns_record_set" "prometheus" {
  project      = var.dns_managed_zone_project_id
  count        = var.prometheus_ingress_enabled == true && var.dns_managed_zone != "" ? 1 : 0
  name         = "${local.prometheus_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_managed_zone
  rrdatas      = [google_compute_global_address.prometheus[count.index].address]
}

# Provision a Public DNS name for grafana.
resource "google_dns_record_set" "prometheus_public" {
  project      = var.dns_public_zone_project_id
  count        = var.prometheus_ingress_enabled == true && var.dns_public_zone != "" ? 1 : 0
  name         = "${local.prometheus_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_public_zone
  rrdatas      = [google_compute_global_address.prometheus[count.index].address]
}

resource "kubernetes_secret" "prometheus_pki" {
  count = var.google_managed_cert == false && var.prometheus_ingress_enabled == true ? 1 : 0
  metadata {
    name      = local.prometheus_cert_name
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = nonsensitive(var.prometheus_tls_cert)
    "tls.key" = nonsensitive(var.prometheus_tls_private_key)
  }
}

#  if prometheus_to_stackdriver_enabled == true, creates configmap with configs to relabel metrics before sending to stackdriver
resource "kubernetes_config_map" "config_file_for_sidecar" {
  count = var.prometheus_to_stackdriver_enabled == true ? 1 : 0
  metadata {
    namespace = var.namespace
    name      = local.config_file_name
  }

  data = {
    "sd-sidecar-configfile.yaml" = "${file("${path.module}/values/config.yaml")}"
  }
}

# if prometheus_to_stackdriver_enabled == true, locals object definition is used to build out stackdriver sidecar
locals {
  config_file_name = "sd-sidecar-configfile"

  join_prometheus_metrics = join("|", var.stackdriver_metrics_filter)
}


# creates storage class to be used with prometheus
resource "kubernetes_storage_class" "pd_ssd" {
  metadata {
    name = terraform.workspace == "default" ? "pd-ssd" : replace(substr("rev-pd-ssd-${local.env.short_id}-${var.suffix}", 0, 30), "-", "")
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  parameters = {
    type = "pd-ssd"
  }
  volume_binding_mode = "WaitForFirstConsumer"
  depends_on = [
    var.namespace,
    var.gke_cluster_name
  ]
}

resource "google_compute_global_address" "prometheus" {
  count       = var.prometheus_ingress_enabled == true ? 1 : 0
  project     = var.project_id
  name        = "global-prometheus-ip-${local.env.short_id}-${var.suffix}"
  description = "Reservation for prometheus IP"
}


##########################
# Alertmanager Resources #
##########################

# GCP Ingress Custom Resources that utilizes iap for use with google auth magic
resource "helm_release" "alertmanager_gcp_ingress_configs" {
  name             = "alertmanager"
  count            = var.alertmanager_ingress_enabled == true ? 1 : 0
  namespace        = var.namespace
  chart            = "${path.module}/charts/gcp-ingress-configs"
  create_namespace = "false"
  max_history      = 10
  values = [
    <<-EOT
    FrontendConfig:
      name: alertmanager
      spec:
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#https_redirect
        redirectToHttps:
          enabled: true
    BackendConfig:
      name: alertmanager
      spec:
        healthCheck:
          type: HTTP
          requestPath: /-/ready
          port: 9093
      logging:
        enable: true
        # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#direct_health
    EOT
  ]
}

# Create kubernetes secret to store the Alertmanager PKI
resource "kubernetes_secret" "alertmanager_pki" {
  count = var.google_managed_cert == false && var.alertmanager_ingress_enabled == true ? 1 : 0
  metadata {
    name      = local.alertmanager_cert_name
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = nonsensitive(var.alertmanager_tls_cert)
    "tls.key" = nonsensitive(var.alertmanager_tls_private_key)
  }
}

# Provision a Private DNS name for prometheus.
resource "google_dns_record_set" "alertmanager" {
  project      = var.dns_managed_zone_project_id
  count        = var.alertmanager_ingress_enabled == true && var.dns_managed_zone != "" ? 1 : 0
  name         = "${local.alertmanager_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_managed_zone
  rrdatas      = [google_compute_global_address.alertmanager[count.index].address]
}

# Provision a Public DNS name for prometheus.
resource "google_dns_record_set" "alertmanager_public" {
  project      = var.dns_public_zone_project_id
  count        = var.alertmanager_ingress_enabled == true && var.dns_public_zone != "" ? 1 : 0
  name         = "${local.alertmanager_host}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_public_zone
  rrdatas      = [google_compute_global_address.alertmanager[count.index].address]
}

resource "google_compute_global_address" "alertmanager" {
  count       = var.alertmanager_ingress_enabled == true ? 1 : 0
  project     = var.project_id
  name        = "global-alertmanager-ip-${local.env.short_id}-${var.suffix}"
  description = "Reservation for alertmanager IP"
}



######################################
# kube-prometheus-stack helm release #
######################################
resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = var.namespace
  max_history      = 10
  repository       = var.chart_repository
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  wait             = false
  create_namespace = false

  values = [
    nonsensitive(templatefile("${path.module}/values/kube-prometheus-stack.yaml", {
      PROMETHEUS_STORAGE_CLASS_NAME         = kubernetes_storage_class.pd_ssd.metadata.0.name
      COMMON_LABEL                          = var.prom_stack_common_label
      GRAFANA_DASHBOARD_LABEL               = var.grafana_dashboard_label
      ALERTMANAGER_STORAGE_CLASS_NAME       = "standard"
      ALERTMANAGER_REPLICAS                 = var.alertmanager_replicas
      ALERTMANAGER_LOG_LEVEL                = var.alertmanager_log_level
      ALERTMANAGER_ALERTS_TO_SILENCE        = var.alertmanager_alerts_to_silence
      ALERTMANAGER_ENABLED                  = var.alertmanager_enabled
      GRAFANA_HOST_NAME                     = local.grafana_host
      PROMETHEUS_HOST_NAME                  = local.prometheus_host
      ALERTMANAGER_HOST_NAME                = local.alertmanager_host
      GRAFANA_IP_NAME                       = local.grafana_ip_name
      PROMETHEUS_IP_NAME                    = local.prometheus_ip_name
      ALERTMANAGER_IP_NAME                  = local.alertmanager_ip_name
      GRAFANA_INGRESS_ENABLED               = var.grafana_ingress_enabled
      PROMETHEUS_INGRESS_ENABLED            = var.prometheus_ingress_enabled
      ALERTMANAGER_INGRESS_ENABLED          = var.alertmanager_ingress_enabled
      GRAFANA_PKI                           = var.google_managed_cert == false ? local.grafana_cert_name : ""
      KUBERNETES_SERVICE_ACCOUNT            = kubernetes_service_account.kube_prometheus_stack.metadata.0.name
      CLIENT_SECRET                         = var.grafana_oauth_client_secret
      CLIENT_ID                             = var.grafana_oauth_client_id
      GRAFANA_INGRESS_CONFIGS               = "grafana"
      PROMETHEUS_INGRESS_CONFIGS            = "prometheus"
      ALERTMANAGER_INGRESS_CONFIGS          = "alertmanager"
      GRAFANA_ADDITIONAL_DATASOURCES        = (var.grafana_additional_datasources)
      NAMESPACE                             = var.namespace
      ENV                                   = var.env
      GOOGLE_APPLICATION_CREDENTIALS_SECRET = var.google_application_credentials_secret
      PROMETHEUS_LOG_LEVEL                  = var.prometheus_log_level
      MONITORING_SERVICE_ACCOUNT_EMAIL      = google_service_account.kube_prometheus_stack.email
      metrics_scope_project_id              = var.metrics_scope_project_id
      GKE_CLUSTER_NAME                      = var.gke_cluster_name
      PROMETHEUS_RESOURCES                  = var.prometheus_resources
      ALERTMANAGER_RESOURCES                = var.alertmanager_resources
      GRAFANA_RESOURCES                     = var.grafana_resources
      PROMETHEUS_TO_STACKDRIVER_ENABLED     = var.prometheus_to_stackdriver_enabled
      PROMETHEUS_RETENTION_SIZE_GB          = var.prometheus_retention_size_gb
      PROMETHEUS_RETENTION_LENGTH           = var.prometheus_retention_length
      PROMETHEUS_REPLICAS                   = var.prometheus_replicas
      PROMETHEUS_TO_STACKDRIVER_CONFIG_FILE = local.config_file_name
      PROMETHEUS_TO_STACKDRIVER_FILTER      = local.join_prometheus_metrics
      PROMETHEUS_ENABLED                    = var.prometheus_enabled
      GRAFANA_ENABLED                       = var.grafana_enabled
      GRAFANA_REPLICAS                      = var.grafana_replicas
      GRAFANA_STORAGE_CLASS_NAME            = "standard"
      GRAFANA_GOOGLE_AUTH_ENABLED           = var.grafana_oidc_enabled
      GRAFANA_PLUGINS                       = var.grafana_plugins
      GRAFANA_ADMIN_PASSWORD                = var.grafana_admin_password
      RBAC                                  = var.rbac
      PROM_OPERATOR_ENABLED                 = terraform.workspace == "default" ? "true" : "false"
      PSP                                   = terraform.workspace == "default" ? "true" : "false"
      GOOGLE_MANAGED_CERT                   = var.google_managed_cert
      GRAFANA_CERT_NAME                     = local.grafana_cert_name
      PROMETHEUS_CERT_NAME                  = local.prometheus_cert_name
      ALERTMANAGER_CERT_NAME                = local.alertmanager_cert_name
      ADDITIONAL_SCRAPE_CONFIGS = var.prometheus_scrape_configs != null ? [
        for job in var.prometheus_scrape_configs : {
          job_name        = try(job.job_name, "")
          metrics_path    = try(job.metrics_path, "/metrics")
          scheme          = try(job.scheme, "https")
          target          = try(job.target, [""])
          param_key       = try(job.param_key, "")
          param_value     = try(job.param_value, "")
          scrape_timeout  = try(job.scrape_timeout, "10s")
          scrape_interval = try(job.scrape_interval, "1m")
        }
      ] : [""]
      ALERTMANAGER_WEBHOOK_RECEIVERS = var.alertmanager_webhook_receivers != null ? [
        for channel in var.alertmanager_webhook_receivers : {
          name                  = try(channel.receiver_name, "")
          endpoint              = try(channel.endpoint, "")
          match_namespace       = try(channel.match_namespace, "")
          match_alertname       = try(channel.match_alertname, "")
          group_by              = try(channel.group_by, "")
          repeat_interval       = try(channel.repeat_interval, "")
          match_gitlab_group_id = try(channel.match_gitlab_group_id, "")
          match_gitlab_repo     = try(channel.match_repo, "")
          continue              = try(channel.continue, false)
          send_resolved         = try(channel.send_resolved, false)
        }
      ] : [""]
    }))
  ]
}

resource "helm_release" "pushgateway" {
  name      = "pushgateway"
  count     = var.pushgateway_enabled == true ? 1 : 0
  namespace = var.namespace
  chart     = "${path.module}/charts/prometheus-pushgateway"

  max_history = 10

  values = [
    <<-EOT
      resources:
        limits:
          cpu: ${var.pushgateway_resource_cpu_limit}
          memory: ${var.pushgateway_resource_memory_limit}
        requests:
          cpu: ${var.pushgateway_resource_cpu_requests}
          memory: ${var.pushgateway_resource_memory_requests}
      serviceMonitor:
        namespace: ${var.namespace}
        prometheusServiceMonitorLabel: ${var.prom_stack_common_label}
      resources:
        limits:
          cpu: ${var.pushgateway_resource_cpu_limit}
          memory: ${var.pushgateway_resource_memory_limit}
        requests:
          cpu: ${var.pushgateway_resource_cpu_requests}
          memory: ${var.pushgateway_resource_memory_requests}
    EOT
  ]
}