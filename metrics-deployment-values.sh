#!/usr/bin/env bash
set -euo pipefail

read -rsp "Grafana Cloud API token: " GF_TOKEN
echo

helm repo add grafana https://grafana.github.io/helm-charts &&
  helm repo update &&
  helm upgrade --install --rollback-on-failure --timeout 300s grafana-k8s-monitoring grafana/k8s-monitoring \
    --version "^4" --namespace "monitoring" --create-namespace --values - <<EOF
cluster:
  name: nowchess
destinations:
  grafana-cloud-metrics:
    type: prometheus
    url: https://prometheus-prod-65-prod-eu-west-2.grafana.net/api/prom/push
    auth:
      type: basic
      username: "3192630"
      password: ${GF_TOKEN}
  grafana-cloud-logs:
    type: loki
    url: https://logs-prod-012.grafana.net/loki/api/v1/push
    auth:
      type: basic
      username: "1591990"
      password: ${GF_TOKEN}
  gc-otlp-endpoint:
    type: otlp
    url: https://otlp-gateway-prod-eu-west-2.grafana.net/otlp
    auth:
      type: basic
      username: "1634203"
      password: ${GF_TOKEN}
clusterMetrics:
  enabled: false
  collector: alloy-metrics
hostMetrics:
  enabled: false
  collector: alloy-metrics
  linuxHosts:
    enabled: false
  windowsHosts:
    enabled: false
clusterEvents:
  enabled: true
  collector: alloy-singleton
  namespaces:
    - nowchess
    - nowchess-staging
podLogsViaLoki:
  enabled: true
  collector: alloy-logs
  namespaces:
    - nowchess
    - nowchess-staging
applicationObservability:
  enabled: true
  collector: alloy-receiver
  receivers:
    otlp:
      grpc:
        enabled: true
      http:
        enabled: true
annotationAutodiscovery:
  enabled: true
  collector: alloy-metrics
  namespaces:
    - nowchess
    - nowchess-staging
  metricsTuning:
    includeMetrics:
      - nowchess.*
      - http_server.*
      - grpc_server.*
      - grpc_client.*
      - redis.*
      - worker_pool.*
      - process_cpu.*
      - process_uptime.*
      - jvm_memory.*
      - jvm_threads.*
      - jvm_gc.*
  extraMetricProcessingRules: |
    rule {
      action       = "drop"
      source_labels = ["__name__"]
      regex        = ".*_bucket"
    }
    rule {
      action = "labeldrop"
      regex  = "(uri|url|exception|outcome|method|methodType|local_address|remote_address|target_addr|instance|pod)"
    }
collectors:
  alloy-metrics:
    presets:
      - clustered
      - statefulset
  alloy-singleton:
    presets:
      - singleton
  alloy-logs:
    presets:
      - filesystem-log-reader
      - daemonset
  alloy-receiver:
    presets:
      - deployment
collectorCommon:
  alloy:
    remoteConfig:
      enabled: true
      url: https://fleet-management-prod-011.grafana.net
      auth:
        type: basic
        username: "1634203"
        password: ${GF_TOKEN}
telemetryServices:
  kube-state-metrics:
    deploy: false
  node-exporter:
    deploy: true
  windows-exporter:
    deploy: false
EOF
