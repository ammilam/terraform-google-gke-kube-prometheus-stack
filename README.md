# kube-prometheus-stack module

This sub-directory contains a terraform module that will deploy a kube-prometheus-stack helm chart and supporting resources. The helm chart is configured to use a GCE ingress with Google OAUTH for authentication, because of this this module has a few requirements to make this happen.

## Table of Contents

* [Prerequisites](#prerequisites)
* [Configuring Kubernetes and Helm Providers](#configuring-kubernetes-and-helm-providers)
* [Usage](#usage)
* [Configuration Options](#configuration-options)
  * [Prometheus](#prometheus)
    * [Prometheus Scrape Configs](#prometheus-scrape-configs)
      * [Example Scrape Config](#example-scrape-config)
    * [Prometheus Rules](#prometheus-rules)
      * [Example PrometheusRule](#example-prometheusrule)
  * [Alertmanager](#alertmanager)
    * [Google Chat Alert Channels](#google-chat-alert-channels)
      * [Example Google Chat Alert Channel](#example-google-chat-alert-channel)
  * [Grafana](#grafana)
    * [Grafana Dashboards](#grafana-dashboards)

## Prerequisites

* Have a GKE cluster to deploy this into in the first place
* Have a Google monitoring scope created with the cluster project joined to it, see the [monitoring module](../monitoring)
* Have helm and kubernetes provider configs that reference a gke cluster's endpoint, cluster cert, and oauth access token

## Configuring Kubernetes and Helm Providers

In order to deploy resources onto a GKE cluster, you must configure the related Terraform providers with the necessary data. This module uses `kubernetes` and `helm` Terraform providers, so configs should wind up looking like the following example...

```terraform
provider "kubernetes" {
  alias                  = "name-me" # name this something that makes sense
  host                   = # reference cluster endpoint here
  cluster_ca_certificate = # reference cluster ca certificate here
  token                  = # reference google_oauth_access_token here
}

provider "helm" {
  alias = "name-me" # name this something that makes sense
  kubernetes {
  host                   = # reference cluster endpoint here
  cluster_ca_certificate = # reference cluster ca certificate here
  token                  = # reference google_oauth_access_token here
  }
}
```

## Usage

Once all the prerequisites are taken care of, define a `kube_prometheus_stack` module like below...

```terraform

# Deploys kube-prometheus-stack
module "kube_prometheus_stack" {

  providers = {
    kubernetes = # reference kubernetes provider config here
    helm       = # reference helm provider config here
  }

  source                = "<source>"
  project_id            = "" # project_id containing the cluster
  metrics_scope_project_id = # monitoring scope project id to get gcp metrics
  dns_managed_zone      = # dns managed zone for dns record creation
  dns_public_zone_project_id        = # project containing dns managed zone for dns record creation
  dns_name              = # dns managed zone name for dns record creation
  gke_cluster_name      = # pass in variable for gke cluster

  # prometheus configs
  prometheus_enabled                  = true
  prometheus_ingress_enabled          = false
  prometheus_replicas                 = 2
  prometheus_resource_cpu_limit       = "2"
  prometheus_resource_memory_limit    = "8Gi"
  prometheus_resource_cpu_requests    = "2"
  prometheus_resource_memory_requests = "6Gi"
  prometheus_retention_size_gb        = "200"
  prometheus_to_stackdriver_enabled    = true # if set to true, as stackdriver sidecar is added to prometheus that sends selected variables
  stackdriver_metrics_filter          = ["prometheus_metric", "prometheus_metric"] # pass in list of metrics to send from prometheus to stackdriver
  # adds new prometheus scrape configs
  prometheus_scrape_configs = ([
     {
      job_name        = "" # name of the Prometheus scrape job
      metrics_path    = "/metrics" # path the scrape target exposes metrics on
      scheme          = "" # http|https
      target          = [""] # list of targets to scrape from
      scrape_timeout  = "" # timeout interval for the scrape config
      scrape_interval = "" # frequency of the metrics scrape
      param_key       = "" # part of k/v used for adding parameters to the scraped url, like auth tokens
      param_value     = "" # part of k/v used for adding parameters to the scraped url, like auth tokens
    }
  ])

  # alertmanager configs
  alertmanager_enabled                  = true
  alertmanager_ingress_enabled          = false
  alertmanager_replicas                 = 1
  alertmanager_resource_cpu_limit       = "500m"
  alertmanager_resource_memory_limit    = "256Mi"
  alertmanager_resource_cpu_requests    = "200m"
  alertmanager_resource_memory_requests = "128Mi"
  enable_calert                             = true
  enable_alertmanager_cloudfunction_routing = false
  alertmanager_alerts_to_silence            = "alert1|alert2" # pass in | separated string  of alerts to silence
  alertmanager_chat_alert_channels          = ([
    {
  # list of google chat webhook receivers
      alertmanager_receiver_name = "" # name of the receiver to create
      match_alertname            = "" # filter for alerts to route here by alertname
      match_namespace            = "" # filter for alerts to route here by namespace
      endpoint                   = "" # google chat webhook url
    },
  ])

  # grafana configs
  grafana_enabled                  = true
  grafana_ingress_enabled          = false
  grafana_replicas                 = 2
  grafana_replicas                 = 1
  grafana_resource_cpu_limit       = "500m"
  grafana_resource_memory_limit    = "256Mi"
  grafana_resource_cpu_requests    = "200m"
  grafana_resource_memory_requests = "128Mi"
  # fields required if grafana_ingress_enabled = true
  grafana_tls_cert                 = "" # value containing grafana tls cert
  grafana_tls_private_key          = "" # value containing grafana tls private key
  grafana_oauth_client_id          = "" # value containing grafana oauth client id, created outside of automation
  grafana_oauth_client_secret      = "" # value containing grafana oauth client secret, created outside of automation
}
```

## Configuration Options

Below are details on configuration options for the various resources deployed in this module, as well as how to deploy things like grafana dashboards, prometheus, rules, or alert channels.

### Prometheus

#### Prometheus Scrape Configs

In order to configure additional scrape configs for Prometheus outside of a service monitor, a scrape config can be created using the `prometheus_scrape_configs` variable. See below for field definitions and an example...

```terraform
prometheus_scrape_configs = ([
    {
      job_name        = "" # name of the Prometheus scrape job
      metrics_path    = "/metrics" # path the scrape target exposes metrics on
      scheme          = "" # http|https
      target          = [""] # list of targets to scrape from
      scrape_timeout  = "" # timeout interval for the scrape config
      scrape_interval = "" # frequency of the metrics scrape
      param_key       = "" # part of k/v used for adding parameters to the scraped url, like auth tokens
      param_value     = "" # part of k/v used for adding parameters to the scraped url, like auth tokens
    }
  ])
  ```

##### Example Scrape Config

Below is an additional scrape config used in the shared services implementation, contained under [/infra/main.tf](/infra/main.tf).

```terraform
prometheus_scrape_configs = ([
    {
      job_name        = "gitlab"
      metrics_path    = "/-/metrics"
      scheme          = "https"
      target          = ["gitlab.com"]
      scrape_timeout  = "30s"
      scrape_interval = "1m"
      param_key       = "token"
      param_value     = "gitlab-token"
    }
  ])
```

#### Prometheus Rules

Prometheus Rules can easily be defined using a custom [Prometheus Rule Helm Chart](/charts/prometheus-rule). The helm chart simply gives an easy, repeatable way to deploy prometheus rules using a `helm_release` terraform definition. The [Prometheus Rule Helm Chart](/charts/prometheus-rule) follows the guidelines laid out by the actual PrometheusRule resource. Refer to the links below for more information on Prometheus Query Language and the PrometheusRule CRD.

* [Prometheus Query Language Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
* [PrometheusRule CRD Documentation](https://docs.openshift.com/container-platform/4.4/rest_api/monitoring_apis/prometheusrule-monitoring-coreos-com-v1.html)

See below for field definitions and an example...

```terraform
resource "helm_release" "consul_prometheus_rule" {
  name             = ""
  namespace        = ""
  repository       = "https://artifactory.company.com/artifactory/company-helm"
  chart            = ""
  version          = "0.1.6"
  create_namespace = "false"
  max_history      = 10

  values = [
    <<-EOT
    ruleName:                # name of the PrometheusRule CRD
    namespace:               # namespace to deploy the rule
    commonLabels:            # assign common label for rule ingestion
    groups:
    - name: group-of-alerts  # name for a grouping of alerts, will correspond to a resource, domain, or team
      rules:                 # accepts list of alert definitons
      - alert:               # alert name
        for: 1m              # threshold duration
        labels:              # labels can be added here
          severity: critical # like severity
        annotations:
          message: Enter in labels to be delivered as an alert message to the recipient
        expr:                # PromQL query
    EOT
  ]
}
```

##### Example PrometheusRule

Below is a PrometheusRule config used in the shared services implementation, contained under [/infra/prometheus-resources/gitlab-rules.tf](/infra/prometheus-resources/gitlab-rules.tf).

```terraform
resource "helm_release" "gitlab_prometheus_rule" {
  name             = "gitlab-prometheus-rules"
  namespace        = var.monitoring_namespace
  repository       = "https://artifactory.company.com/artifactory/company-helm"
  chart            = "prometheus-rule"
  version          = "0.1.6"
  create_namespace = "false"
  max_history      = 10

  values = [
    <<-EOT
    ruleName: gitlab
    namespace: ${var.monitoring_namespace}
    commonLabels: ${var.prom_stack_common_label}
    groups:
    - name: gitlab.rules
      rules:
      - alert: CWOWGitlabReviewStageFailures
        expr: sum by(project, kind, ref, stage, status, job_name) (gitlab_ci_pipeline_job_status{job="cwow-gitlab-ci-pipelines-exporter",job_name=~".+(stop|review).*",kind="merge-request",status="failed"}) >0
        for: 12h
        labels:
          severity: critical
          application: gitlab
        annotations:
          summary: 'Gitlab stop|review stage has been in failure for >12 hours, environments likely need to be cleaned up'
          merge_request: 'https://gitlab.gcp.company.com/{{ $labels.project }}/-/merge_requests/{{ $labels.ref }}'
          project: '{{ $labels.project }}'
          job_name:  '{{ $labels.job_name }}'
          status: '{{ $labels.status }}'
    EOT
  ]
}
```

### Alertmanager

#### Google Chat Alert Channels

Once an alert rule has been defined, as detailed under [Prometheus Rules](#prometheus-rules), it can be routed to a Google Chat room using `calert`. If the `enable_calert` flag is set to `true` a calert instance will be deployed alongside the rest of the resources in the monitoring namespace. Channels are created by passing a list of configs into the `alertmanager_chat_alert_channels` variable as detailed below...

```terraform
  enable_calert                             = true # deploys a calert instance

  # creates the chat channels
  alertmanager_chat_alert_channels          = ([
    {
      alertmanager_receiver_name = "" # name of the receiver to create
      match_alertname            = "" # filter for alerts to route here by alertname
      match_namespace            = "" # filter for alerts to route here by namespace
      endpoint                   = "" # google chat webhook url
    },
  ```

##### Example Google Chat Alert Channel

Below is a Google Chat alert channel used in the shared services implementation, contained under [/infra/main.tf](/infra/main.tf).

```terraform
chat_channels = ([

    # consul support channel
    {
      alertmanager_receiver_name = "consul"                      # names the receiver
      match_namespace            = "consul"                      # filters for all rules in the consul namespace
      endpoint                   = "https://chat.googleapis...." # webhook endpoint for the alert
    },
  ])

```

### Grafana

#### Grafana Dashboards

Grafana Dashboards are deployed via the [grafana-dashboards module](/modules/grafana-dashboards).

In order to start provisioning Grafana dashboards, simply create a directory and fill it with your favorite Grafana dashboards in valid [Grafana Dashboards Format](https://grafana.com/docs/grafana/latest/dashboards/json-model/) (if in doubt, make it in the gui and [export it](https://grafana.com/docs/grafana/latest/dashboards/export-import/)), then reference the directory in a module definiton like the example below...


```terraform
# grafana dashboards module
module "grafana_dashboards" {

  source                       = "git::https://gitlab.gcp.company.com/shared-services/monitoring.git//modules/grafana-dashboards?ref=<most-recent-tag>"
  grafana_dashboards_directory = "${path.module}/grafana-dashboards" # directory containing the dashboards
  monitoring_namespace         = module.kube_prometheus_stack.monitoring_namespace
}
```

##### Example Grafana Dashboards

Below is the shared services implementation, contained under [/infra/main.tf](/infra/main.tf).

```terraform
module "grafana_dashboards" {

  source                       = "git::https://gitlab.gcp.company.com/shared-services/monitoring.git//modules/grafana-dashboards?ref=<most-recent-tag>"
  grafana_dashboards_directory = "${path.module}/grafana-dashboards"
  monitoring_namespace         = module.kube_prometheus_stack.monitoring_namespace
  grafana_dashboard_label      = local.grafana_dashboard_label
}
```
